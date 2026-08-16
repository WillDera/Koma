//! EPUB → `.koma` compile, KIR decode, scene chrome, and layout boxes.
//!
//! Does not link `koma-renderer` (no wgpu). Layout is cosmic-text in this
//! crate. Flutter still paints; Level 3 consumes glyph boxes for paginate
//! and hit-test. Scene effects stay inert.

use std::collections::HashMap;
use std::io::Cursor;

use koma_compiler::{KomaCompiler, KomaPackage};
use koma_core::adapters::{ContentAdapter, ContentSource};
use koma_core::kir::{block, list_block, Block, Chapter, TextSpan};
use koma_epub::EpubAdapter;
use koma_scene::{EnvironmentKind, Scene, TransitionKind};

/// Manifest row for one spine chapter.
#[derive(Clone, Debug)]
pub struct KomaChapterInfo {
    pub id: String,
    pub title: Option<String>,
}

/// Inline run. KIR `SpanStyle` has no href/code; those stay on the HTML path.
#[derive(Clone, Debug)]
pub struct KirSpanDto {
    pub text: String,
    pub bold: bool,
    pub italic: bool,
    pub underline: bool,
    pub color: Option<String>,
}

/// One KIR block, with quote/list children nested (Dart flattens).
#[derive(Clone, Debug)]
pub struct KirBlockDto {
    /// `paragraph`, `heading1`…`heading6`, `image`, `media`, `quote`, `list`.
    pub kind: String,
    pub spans: Vec<KirSpanDto>,
    pub media_id: Option<String>,
    pub alt: Option<String>,
    pub ordered: bool,
    pub children: Vec<KirBlockDto>,
}

#[derive(Clone, Debug)]
pub struct KirChapterDto {
    pub id: String,
    pub title: Option<String>,
    pub blocks: Vec<KirBlockDto>,
}

/// Presentation chrome only — not the effect graph or typography.
#[derive(Clone, Debug)]
pub struct SceneChromeDto {
    /// `indoor`, `outdoor`, `space`, or `abstract`.
    pub environment_kind: String,
    pub background_hex: String,
    pub ambient_hex: String,
    pub ambient_intensity: f64,
    pub frost: f64,
    pub fade_seconds: f64,
}

#[derive(Clone, Debug)]
pub struct ChapterPayloadDto {
    pub chapter: KirChapterDto,
    pub scene: Option<SceneChromeDto>,
}

/// Compile an EPUB file on disk into `.koma` zip bytes (default theme).
pub fn compile_epub(path: String) -> Result<Vec<u8>, String> {
    let source = ContentSource::new(&path).with_format("epub");
    let document = EpubAdapter
        .to_kir(&source)
        .map_err(|e| e.to_string())?;
    let mut buf = Cursor::new(Vec::new());
    KomaCompiler
        .compile(&document, &HashMap::new(), &mut buf)
        .map_err(|e| e.to_string())?;
    Ok(buf.into_inner())
}

/// Chapter ids/titles from a `.koma` file (manifest only).
pub fn package_chapters(koma_path: String) -> Result<Vec<KomaChapterInfo>, String> {
    let pkg = KomaPackage::open_file(&koma_path).map_err(|e| e.to_string())?;
    Ok(pkg
        .manifest()
        .chapters
        .iter()
        .map(|c| KomaChapterInfo {
            id: c.id.clone(),
            title: c.title.clone(),
        })
        .collect())
}

/// Decode one chapter by spine index from a `.koma` file.
pub fn chapter_kir_by_index(koma_path: String, index: u32) -> Result<KirChapterDto, String> {
    Ok(chapter_payload_by_index(koma_path, index)?.chapter)
}

/// KIR plus scene chrome in one zip open.
pub fn chapter_payload_by_index(
    koma_path: String,
    index: u32,
) -> Result<ChapterPayloadDto, String> {
    let mut pkg = KomaPackage::open_file(&koma_path).map_err(|e| e.to_string())?;
    let chapter = pkg
        .chapter_by_index(index as usize)
        .map_err(|e| e.to_string())?;
    let id = chapter.id.clone();
    let scene = pkg.scene(&id).ok().map(scene_to_chrome);
    Ok(ChapterPayloadDto {
        chapter: chapter_to_dto(chapter),
        scene,
    })
}

/// Layout one chapter into page-sized glyph boxes (Level 3).
///
/// Flutter still paints. Offsets are into the returned `plain_text`, which
/// matches `KirToDocument` (no chapter title, images 0 chars).
pub fn layout_chapter_pages(
    koma_path: String,
    index: u32,
    width: u32,
    height: u32,
    font_size: f64,
    line_height: f64,
    margin: f64,
) -> Result<LayoutResultDto, String> {
    let mut pkg = KomaPackage::open_file(&koma_path).map_err(|e| e.to_string())?;
    let chapter = pkg
        .chapter_by_index(index as usize)
        .map_err(|e| e.to_string())?;
    let result = crate::kre_layout::layout_chapter(
        &chapter,
        crate::kre_layout::LayoutParams {
            width,
            height,
            margin: margin as f32,
            font_size: font_size as f32,
            line_height: line_height as f32,
            paragraph_spacing: (line_height as f32) * 0.4,
        },
    );
    Ok(layout_result_to_dto(result))
}

#[derive(Clone, Debug)]
pub struct LayoutGlyphDto {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub char_start: u32,
    pub char_end: u32,
}

#[derive(Clone, Debug)]
pub struct LayoutLineDto {
    pub y: f64,
    pub height: f64,
    pub char_start: u32,
    pub char_end: u32,
    pub glyphs: Vec<LayoutGlyphDto>,
}

#[derive(Clone, Debug)]
pub struct LayoutPageDto {
    pub char_start: u32,
    pub char_end: u32,
    pub lines: Vec<LayoutLineDto>,
}

#[derive(Clone, Debug)]
pub struct LayoutResultDto {
    pub plain_text: String,
    pub pages: Vec<LayoutPageDto>,
}

fn layout_result_to_dto(r: crate::kre_layout::LayoutResult) -> LayoutResultDto {
    LayoutResultDto {
        plain_text: r.plain_text,
        pages: r
            .pages
            .into_iter()
            .map(|p| LayoutPageDto {
                char_start: p.char_start,
                char_end: p.char_end,
                lines: p
                    .lines
                    .into_iter()
                    .map(|l| LayoutLineDto {
                        y: l.y as f64,
                        height: l.height as f64,
                        char_start: l.char_start,
                        char_end: l.char_end,
                        glyphs: l
                            .glyphs
                            .into_iter()
                            .map(|g| LayoutGlyphDto {
                                x: g.x as f64,
                                y: g.y as f64,
                                width: g.width as f64,
                                height: g.height as f64,
                                char_start: g.char_start,
                                char_end: g.char_end,
                            })
                            .collect(),
                    })
                    .collect(),
            })
            .collect(),
    }
}

fn scene_to_chrome(scene: Scene) -> SceneChromeDto {
    let frost = scene
        .environment
        .atmosphere
        .get("frost")
        .copied()
        .unwrap_or(0.0) as f64;
    let fade_seconds = scene
        .transitions
        .iter()
        .find(|t| t.kind == TransitionKind::Fade)
        .map(|t| t.duration as f64)
        .unwrap_or(0.6);
    let kind = match scene.environment.kind {
        EnvironmentKind::Indoor => "indoor",
        EnvironmentKind::Outdoor => "outdoor",
        EnvironmentKind::Space => "space",
        EnvironmentKind::Abstract => "abstract",
    };
    SceneChromeDto {
        environment_kind: kind.into(),
        background_hex: scene.environment.background.to_hex(),
        ambient_hex: scene.lighting.ambient.color.to_hex(),
        ambient_intensity: scene.lighting.ambient.intensity as f64,
        frost,
        fade_seconds,
    }
}

fn chapter_to_dto(chapter: Chapter) -> KirChapterDto {
    let mut blocks = Vec::new();
    for section in &chapter.sections {
        for b in &section.blocks {
            blocks.push(block_to_dto(b));
        }
    }
    KirChapterDto {
        id: chapter.id,
        title: chapter.title,
        blocks,
    }
}

fn block_to_dto(block: &Block) -> KirBlockDto {
    match &block.kind {
        Some(block::Kind::Paragraph(p)) => KirBlockDto {
            kind: "paragraph".into(),
            spans: spans_to_dto(&p.spans),
            media_id: None,
            alt: None,
            ordered: false,
            children: Vec::new(),
        },
        Some(block::Kind::Heading(h)) => {
            let level = h.level.clamp(1, 6);
            KirBlockDto {
                kind: format!("heading{level}"),
                spans: spans_to_dto(&h.spans),
                media_id: None,
                alt: None,
                ordered: false,
                children: Vec::new(),
            }
        }
        Some(block::Kind::Image(i)) => KirBlockDto {
            kind: "image".into(),
            spans: Vec::new(),
            media_id: Some(i.media_id.clone()),
            alt: i.alt.clone(),
            ordered: false,
            children: Vec::new(),
        },
        Some(block::Kind::Media(m)) => KirBlockDto {
            kind: "media".into(),
            spans: Vec::new(),
            media_id: Some(m.media_id.clone()),
            alt: m.caption.clone(),
            ordered: false,
            children: Vec::new(),
        },
        Some(block::Kind::Quote(q)) => KirBlockDto {
            kind: "quote".into(),
            spans: Vec::new(),
            media_id: None,
            alt: q.attribution.clone(),
            ordered: false,
            children: q.content.iter().map(block_to_dto).collect(),
        },
        Some(block::Kind::List(l)) => KirBlockDto {
            kind: "list".into(),
            spans: Vec::new(),
            media_id: None,
            alt: None,
            ordered: l.kind == list_block::Kind::Ordered as i32,
            children: l.items.iter().map(block_to_dto).collect(),
        },
        None => KirBlockDto {
            kind: "empty".into(),
            spans: Vec::new(),
            media_id: None,
            alt: None,
            ordered: false,
            children: Vec::new(),
        },
    }
}

fn spans_to_dto(spans: &[TextSpan]) -> Vec<KirSpanDto> {
    spans
        .iter()
        .map(|s| {
            let style = s.style.as_ref();
            KirSpanDto {
                text: s.text.clone(),
                bold: style.and_then(|st| st.bold).unwrap_or(false),
                italic: style.and_then(|st| st.italic).unwrap_or(false),
                underline: style.and_then(|st| st.underline).unwrap_or(false),
                color: style.and_then(|st| st.color.clone()),
            }
        })
        .collect()
}
