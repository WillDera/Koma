//! EPUB → `.koma` compile and lazy KIR chapter decode (Level 1).
//!
//! Does not link `koma-renderer`. Layout/pixels stay in Flutter.

use std::collections::HashMap;
use std::io::Cursor;

use koma_compiler::{KomaCompiler, KomaPackage};
use koma_core::adapters::{ContentAdapter, ContentSource};
use koma_core::kir::{block, list_block, Block, Chapter, TextSpan};
use koma_epub::EpubAdapter;

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
    let mut pkg = KomaPackage::open_file(&koma_path).map_err(|e| e.to_string())?;
    let chapter = pkg
        .chapter_by_index(index as usize)
        .map_err(|e| e.to_string())?;
    Ok(chapter_to_dto(chapter))
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
