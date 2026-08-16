//! KRE layout stage (Level 3): wrap, paginate, character offsets.
//!
//! Does **not** link `koma-renderer` (wgpu). Same wrapping idea as
//! `koma-renderer::layout_blocks`, plus what that crate still lacks:
//! - `char_start` / `char_end` on glyphs and lines
//! - page slices that fit in a frame height
//! - image placeholders (height only; 0 characters)
//!
//! Plain text matches Dart `KirToDocument`: no chapter title, `\n\n` between
//! blocks, images contribute 0 chars, list markers are not in the string.
//! `char_start` / `char_end` are Dart `String` indices (UTF-16 code units),
//! not UTF-8 bytes — the same space highlights and TTS already use.

use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;
use std::sync::{Mutex, OnceLock};

use cosmic_text::{Attrs, Buffer, FontSystem, Metrics, Shaping, Wrap};
use koma_core::kir::{block, Block, Chapter, TextSpan};

#[derive(Clone, Debug)]
pub struct LayoutGlyph {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub char_start: u32,
    pub char_end: u32,
}

#[derive(Clone, Debug)]
pub struct LayoutLine {
    pub y: f32,
    pub height: f32,
    pub char_start: u32,
    pub char_end: u32,
    pub glyphs: Vec<LayoutGlyph>,
}

#[derive(Clone, Debug)]
pub struct LayoutPage {
    pub char_start: u32,
    pub char_end: u32,
    pub lines: Vec<LayoutLine>,
}

#[derive(Clone, Debug)]
pub struct LayoutResult {
    pub plain_text: String,
    pub pages: Vec<LayoutPage>,
}

#[derive(Clone, Debug)]
pub struct LayoutParams {
    pub width: u32,
    pub height: u32,
    pub margin: f32,
    pub font_size: f32,
    pub line_height: f32,
    pub paragraph_spacing: f32,
    /// Height reserved on page 0 (chapter title). Later pages use the full frame.
    pub first_page_inset: f32,
    /// TTF/OTF the reader will paint with. Empty = platform default faces.
    pub font_path: String,
}

enum Unit {
    Text {
        start: usize,
        text: String,
        scale: f32,
    },
    Image {
        height: f32,
    },
}

struct Collected {
    plain: String,
    units: Vec<Unit>,
}

fn font_system() -> std::sync::MutexGuard<'static, FontSystem> {
    static FS: OnceLock<Mutex<FontSystem>> = OnceLock::new();
    FS.get_or_init(|| Mutex::new(init_font_system()))
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
}

fn init_font_system() -> FontSystem {
    let mut fs = FontSystem::new();
    // fontdb::load_system_fonts skips Android. cosmic-text also cannot use
    // Source::File faces, so we read a few TTFs into memory.
    if fs.db().is_empty() {
        load_mobile_fonts(fs.db_mut());
        apply_generic_families(fs.db_mut());
    }
    fs
}

fn load_mobile_fonts(db: &mut cosmic_text::fontdb::Database) {
    const CANDIDATES: &[&str] = &[
        "/system/fonts/Roboto-Regular.ttf",
        "/system/fonts/Roboto-Medium.ttf",
        "/system/fonts/Roboto-Bold.ttf",
        "/system/fonts/Roboto-Italic.ttf",
        "/system/fonts/RobotoFlex-Regular.ttf",
        "/system/fonts/NotoSans-Regular.ttf",
        "/system/fonts/NotoSerif-Regular.ttf",
        "/system/fonts/DroidSans.ttf",
        "/system/fonts/DroidSans-Bold.ttf",
    ];
    for path in CANDIDATES {
        load_ttf_binary(db, Path::new(path));
    }
    if !db.is_empty() {
        return;
    }
    for dir in ["/system/fonts", "/product/fonts", "/system/product/fonts"] {
        load_fonts_dir_binary(db, Path::new(dir));
        if !db.is_empty() {
            return;
        }
    }
}

fn load_fonts_dir_binary(db: &mut cosmic_text::fontdb::Database, dir: &Path) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        if db.len() >= 8 {
            break;
        }
        let path = entry.path();
        if path.is_dir() {
            continue;
        }
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("")
            .to_ascii_lowercase();
        if name.contains("emoji") || name.contains("cjk") || name.contains("naskh") {
            continue;
        }
        if !(name.ends_with(".ttf") || name.ends_with(".otf")) {
            continue;
        }
        load_ttf_binary(db, &path);
    }
}

fn load_ttf_binary(db: &mut cosmic_text::fontdb::Database, path: &Path) {
    const MAX_BYTES: u64 = 2 * 1024 * 1024;
    let Ok(meta) = std::fs::metadata(path) else {
        return;
    };
    if meta.len() > MAX_BYTES {
        return;
    }
    let Ok(bytes) = std::fs::read(path) else {
        return;
    };
    db.load_font_data(bytes);
}

/// Load the reader's face and make it the generic family cosmic-text wraps with.
fn ensure_reading_font(fs: &mut FontSystem, path: &str) {
    static FAMILIES: OnceLock<Mutex<HashMap<String, String>>> = OnceLock::new();
    let mut map = FAMILIES
        .get_or_init(|| Mutex::new(HashMap::new()))
        .lock()
        .unwrap_or_else(|poison| poison.into_inner());
    if !map.contains_key(path) {
        const MAX: u64 = 8 * 1024 * 1024;
        let Ok(meta) = std::fs::metadata(path) else {
            return;
        };
        if meta.len() > MAX {
            return;
        }
        let Ok(bytes) = std::fs::read(path) else {
            return;
        };
        let mut probe = cosmic_text::fontdb::Database::new();
        probe.load_font_data(bytes.clone());
        let Some(name) = probe
            .faces()
            .next()
            .and_then(|f| f.families.first().map(|(n, _)| n.clone()))
        else {
            return;
        };
        fs.db_mut().load_font_data(bytes);
        map.insert(path.to_string(), name);
    }
    let name = map.get(path).cloned();
    drop(map);
    if let Some(name) = name {
        fs.db_mut().set_sans_serif_family(&name);
        fs.db_mut().set_serif_family(&name);
        fs.db_mut().set_monospace_family(&name);
    }
}

/// Dart `String.length` units (UTF-16), matching highlights / TTS / substring.
fn utf16_len(s: &str) -> usize {
    s.encode_utf16().count()
}

fn utf8_to_utf16(s: &str, byte: usize) -> u32 {
    let mut byte = byte.min(s.len());
    while byte > 0 && !s.is_char_boundary(byte) {
        byte -= 1;
    }
    s[..byte].encode_utf16().count() as u32
}

fn apply_generic_families(db: &mut cosmic_text::fontdb::Database) {
    const PREFERRED: &[&str] = &["Roboto", "Noto Sans", "Droid Sans", "Noto Serif"];
    let names: Vec<String> = db
        .faces()
        .flat_map(|face| face.families.iter().map(|(n, _)| n.clone()))
        .collect();
    let pick = PREFERRED
        .iter()
        .find(|want| names.iter().any(|n| n == *want))
        .map(|s| (*s).to_string())
        .or_else(|| names.into_iter().next());
    if let Some(name) = pick {
        db.set_sans_serif_family(name.clone());
        db.set_serif_family(name.clone());
        db.set_monospace_family(name);
    }
}

/// Lay out one KIR chapter into page-sized glyph boxes.
pub fn layout_chapter(chapter: &Chapter, params: LayoutParams) -> Result<LayoutResult, String> {
    match catch_unwind(AssertUnwindSafe(|| layout_chapter_inner(chapter, params))) {
        Ok(result) => result,
        Err(_) => Err("text layout panicked (usually a missing font)".into()),
    }
}

fn layout_chapter_inner(
    chapter: &Chapter,
    params: LayoutParams,
) -> Result<LayoutResult, String> {
    let collected = collect(chapter, params.font_size);
    let mut fs = font_system();
    if !params.font_path.is_empty() {
        ensure_reading_font(&mut fs, &params.font_path);
    }
    if fs.db().is_empty() {
        return Err("no fonts available for layout".into());
    }
    let mut lines = Vec::new();
    let mut y = params.margin;
    let text_width = (params.width as f32 - 2.0 * params.margin).max(1.0);

    for unit in &collected.units {
        match unit {
            Unit::Text {
                start,
                text,
                scale,
            } => {
                if text.is_empty() {
                    continue;
                }
                let size = params.font_size * scale;
                let lh = params.line_height * scale;
                let metrics = Metrics {
                    font_size: size,
                    line_height: lh,
                };
                let shaped = shape_block(
                    &mut fs,
                    text,
                    *start as u32,
                    params.margin,
                    y,
                    metrics,
                    text_width,
                );
                for line in &shaped {
                    y = line.y + line.height;
                }
                if shaped.is_empty() {
                    y += lh;
                }
                y += params.paragraph_spacing;
                lines.extend(shaped);
            }
            Unit::Image { height } => {
                // At least as tall as Flutter's `estimateEmbedHeight` default so
                // a figure is a full-width band, not a short stamp with text
                // beside it.
                let h = (*height).max(text_width * 0.55);
                lines.push(LayoutLine {
                    y,
                    height: h,
                    char_start: 0,
                    char_end: 0,
                    glyphs: Vec::new(),
                });
                y += h + params.paragraph_spacing;
            }
        }
    }

    let pages = paginate(
        lines,
        params.height as f32,
        params.margin,
        params.first_page_inset,
    );
    Ok(LayoutResult {
        plain_text: collected.plain,
        pages,
    })
}

/// Pixel → character offset on one page. `None` if the point misses every line.
pub fn hit_test(page: &LayoutPage, x: f32, y: f32) -> Option<u32> {
    for line in &page.lines {
        if y < line.y || y >= line.y + line.height {
            continue;
        }
        if line.glyphs.is_empty() {
            return Some(line.char_start);
        }
        if x < line.glyphs[0].x {
            return Some(line.char_start);
        }
        for g in &line.glyphs {
            if x >= g.x && x < g.x + g.width {
                return Some(g.char_start);
            }
        }
        return Some(line.glyphs.last().unwrap().char_end);
    }
    None
}

pub fn paginate(
    lines: Vec<LayoutLine>,
    page_height: f32,
    margin: f32,
    first_page_inset: f32,
) -> Vec<LayoutPage> {
    if lines.is_empty() {
        return vec![LayoutPage {
            char_start: 0,
            char_end: 0,
            lines: Vec::new(),
        }];
    }
    let body = (page_height - 2.0 * margin).max(margin);
    let mut usable = (body - first_page_inset.max(0.0)).max(1.0);
    let mut pages = Vec::new();
    let mut current: Vec<LayoutLine> = Vec::new();
    let mut origin = lines[0].y;

    for line in lines {
        let depth = line.y + line.height - origin;
        if depth > usable && !current.is_empty() {
            pages.push(rebase_page(std::mem::take(&mut current), origin, margin));
            origin = line.y;
            usable = body;
        }
        current.push(line);
    }
    if !current.is_empty() {
        pages.push(rebase_page(current, origin, margin));
    }
    pages
}

fn rebase_page(lines: Vec<LayoutLine>, origin: f32, margin: f32) -> LayoutPage {
    let char_start = lines
        .iter()
        .filter(|l| !l.glyphs.is_empty())
        .map(|l| l.char_start)
        .min()
        .unwrap_or(0);
    let char_end = lines
        .iter()
        .filter(|l| !l.glyphs.is_empty())
        .map(|l| l.char_end)
        .max()
        .unwrap_or(char_start);
    let lines = lines
        .into_iter()
        .map(|mut l| {
            l.y = margin + (l.y - origin);
            for g in &mut l.glyphs {
                g.y = margin + (g.y - origin);
            }
            l
        })
        .collect();
    LayoutPage {
        char_start,
        char_end,
        lines,
    }
}

fn shape_block(
    fs: &mut FontSystem,
    text: &str,
    base: u32,
    x_margin: f32,
    y0: f32,
    metrics: Metrics,
    text_width: f32,
) -> Vec<LayoutLine> {
    let mut buffer = Buffer::new(fs, metrics);
    buffer.set_size(fs, Some(text_width), None);
    buffer.set_wrap(fs, Wrap::Word);
    buffer.set_text(fs, text, Attrs::new(), Shaping::Advanced);
    buffer.shape_until_scroll(fs, false);

    let mut lines = Vec::new();
    let mut y = y0;
    for run in buffer.layout_runs() {
        let mut glyphs = Vec::with_capacity(run.glyphs.len());
        for glyph in run.glyphs {
            let physical = glyph.physical((x_margin, y), 1.0);
            glyphs.push(LayoutGlyph {
                x: physical.x as f32,
                y: physical.y as f32,
                width: glyph.w,
                height: metrics.line_height,
                char_start: base + utf8_to_utf16(text, glyph.start),
                char_end: base + utf8_to_utf16(text, glyph.end),
            });
        }
        let (char_start, char_end) = if glyphs.is_empty() {
            (base, base)
        } else {
            (glyphs.first().unwrap().char_start, glyphs.last().unwrap().char_end)
        };
        if !glyphs.is_empty() {
            lines.push(LayoutLine {
                y,
                height: metrics.line_height,
                char_start,
                char_end,
                glyphs,
            });
        }
        y += metrics.line_height;
    }
    lines
}

fn collect(chapter: &Chapter, font_size: f32) -> Collected {
    let mut c = Collected {
        plain: String::new(),
        units: Vec::new(),
    };
    for section in &chapter.sections {
        for b in &section.blocks {
            emit_block(&mut c, b, font_size, 1.0);
        }
    }
    c.plain = c.plain.trim_end().to_string();
    c
}

fn emit_block(c: &mut Collected, block: &Block, font_size: f32, scale: f32) {
    match &block.kind {
        Some(block::Kind::Paragraph(p)) => emit_text(c, spans_text(&p.spans), scale),
        Some(block::Kind::Heading(h)) => {
            let s = if h.level <= 1 { 1.5 } else { 1.25 };
            emit_text(c, spans_text(&h.spans), s);
        }
        Some(block::Kind::Image(_)) | Some(block::Kind::Media(_)) => emit_image(c, font_size),
        Some(block::Kind::Quote(q)) => {
            if q.content.is_empty() {
                // attribution-only; nothing in Dart plainText either unless spans
            } else {
                for child in &q.content {
                    emit_block(c, child, font_size, scale);
                }
            }
        }
        Some(block::Kind::List(l)) => {
            for item in &l.items {
                if matches!(&item.kind, Some(block::Kind::List(_))) {
                    emit_block(c, item, font_size, scale);
                } else if matches!(
                    &item.kind,
                    Some(block::Kind::Image(_)) | Some(block::Kind::Media(_))
                ) {
                    emit_image(c, font_size);
                } else {
                    emit_text(c, item.plain_text_spans_only(), scale);
                }
            }
        }
        None => {}
    }
}

trait SpansOnly {
    fn plain_text_spans_only(&self) -> String;
}

impl SpansOnly for Block {
    fn plain_text_spans_only(&self) -> String {
        match &self.kind {
            Some(block::Kind::Paragraph(p)) => spans_text(&p.spans),
            Some(block::Kind::Heading(h)) => spans_text(&h.spans),
            Some(block::Kind::Quote(q)) => q
                .content
                .iter()
                .map(Block::plain_text_spans_only)
                .collect::<Vec<_>>()
                .join(""),
            Some(block::Kind::List(l)) => l
                .items
                .iter()
                .map(Block::plain_text_spans_only)
                .collect::<Vec<_>>()
                .join(""),
            _ => String::new(),
        }
    }
}

fn spans_text(spans: &[TextSpan]) -> String {
    spans.iter().map(|s| s.text.as_str()).collect()
}

fn ensure_gap(plain: &mut String) {
    if plain.is_empty() {
        return;
    }
    if !plain.ends_with('\n') {
        plain.push_str("\n\n");
    }
}

fn emit_text(c: &mut Collected, text: String, scale: f32) {
    if text.is_empty() {
        return;
    }
    ensure_gap(&mut c.plain);
    let start = utf16_len(&c.plain);
    c.plain.push_str(&text);
    c.units.push(Unit::Text { start, text, scale });
    ensure_gap(&mut c.plain);
}

fn emit_image(c: &mut Collected, font_size: f32) {
    ensure_gap(&mut c.plain);
    c.units.push(Unit::Image {
        height: font_size * 8.0,
    });
    ensure_gap(&mut c.plain);
}

#[cfg(test)]
mod tests {
    use koma_core::kir::{paragraph, Block, Chapter, Heading, Section};

    use super::*;

    fn chapter_with(blocks: Vec<Block>) -> Chapter {
        Chapter {
            id: "c1".into(),
            title: Some("Must Not Appear".into()),
            sections: vec![Section {
                id: "s".into(),
                blocks,
            }],
        }
    }

    #[test]
    fn collect_skips_title_and_images_and_gaps_blocks() {
        let ch = chapter_with(vec![
            Block {
                kind: Some(block::Kind::Paragraph(paragraph("Hello"))),
                ..Default::default()
            },
            Block {
                kind: Some(block::Kind::Image(Default::default())),
                ..Default::default()
            },
            Block {
                kind: Some(block::Kind::Paragraph(paragraph("World"))),
                ..Default::default()
            },
        ]);
        let c = collect(&ch, 18.0);
        assert!(!c.plain.contains("Must Not Appear"));
        assert_eq!(c.plain, "Hello\n\nWorld");
        assert!(c.units.iter().any(|u| matches!(u, Unit::Image { .. })));
    }

    #[test]
    fn image_placeholder_is_a_full_width_band_above_following_text() {
        let ch = chapter_with(vec![
            Block {
                kind: Some(block::Kind::Image(Default::default())),
                ..Default::default()
            },
            Block {
                kind: Some(block::Kind::Paragraph(paragraph("After"))),
                ..Default::default()
            },
        ]);
        let result = layout_chapter(
            &ch,
            LayoutParams {
                width: 400,
                height: 800,
                margin: 0.0,
                font_size: 18.0,
                line_height: 28.0,
                paragraph_spacing: 8.0,
                first_page_inset: 0.0,
                font_path: String::new(),
            },
        )
        .expect("layout");
        let image = result.pages[0]
            .lines
            .iter()
            .find(|l| l.glyphs.is_empty())
            .expect("image line");
        assert!(image.height >= 400.0 * 0.55 - 0.5);
        let text = result.pages[0]
            .lines
            .iter()
            .find(|l| !l.glyphs.is_empty())
            .expect("text line");
        assert!(text.y >= image.y + image.height);
    }

    #[test]
    fn paginate_splits_when_lines_overflow() {
        let line = |y: f32, start: u32| LayoutLine {
            y,
            height: 20.0,
            char_start: start,
            char_end: start + 1,
            glyphs: vec![LayoutGlyph {
                x: 0.0,
                y,
                width: 8.0,
                height: 20.0,
                char_start: start,
                char_end: start + 1,
            }],
        };
        // margin 10, page 50 → usable 30. Two 20px lines at y=10 and y=30 overflow.
        let pages = paginate(vec![line(10.0, 0), line(30.0, 1)], 50.0, 10.0, 0.0);
        assert_eq!(pages.len(), 2);
        assert_eq!(pages[0].char_start, 0);
        assert_eq!(pages[1].char_start, 1);
        assert!((pages[0].lines[0].y - 10.0).abs() < f32::EPSILON);
        assert!((pages[1].lines[0].y - 10.0).abs() < f32::EPSILON);
    }

    #[test]
    fn hit_test_returns_glyph_offset() {
        let page = LayoutPage {
            char_start: 0,
            char_end: 4,
            lines: vec![LayoutLine {
                y: 10.0,
                height: 20.0,
                char_start: 0,
                char_end: 4,
                glyphs: vec![LayoutGlyph {
                    x: 48.0,
                    y: 10.0,
                    width: 10.0,
                    height: 20.0,
                    char_start: 2,
                    char_end: 3,
                }],
            }],
        };
        assert_eq!(hit_test(&page, 50.0, 15.0), Some(2));
        assert_eq!(hit_test(&page, 0.0, 0.0), None);
        assert_eq!(hit_test(&page, 70.0, 15.0), Some(3));
    }

    #[test]
    fn first_page_inset_breaks_earlier() {
        let line = |y: f32, start: u32| LayoutLine {
            y,
            height: 20.0,
            char_start: start,
            char_end: start + 1,
            glyphs: vec![LayoutGlyph {
                x: 0.0,
                y,
                width: 8.0,
                height: 20.0,
                char_start: start,
                char_end: start + 1,
            }],
        };
        // body usable 80, inset 50 → first page only fits one 20px line.
        let pages = paginate(
            vec![line(0.0, 0), line(20.0, 1), line(40.0, 2)],
            80.0,
            0.0,
            50.0,
        );
        assert_eq!(pages.len(), 2);
        assert_eq!(pages[0].char_end, 1);
        assert_eq!(pages[1].char_start, 1);
    }

    #[test]
    fn heading_scale_unit() {
        let ch = chapter_with(vec![Block {
            kind: Some(block::Kind::Heading(Heading {
                level: 1,
                spans: paragraph("Title").spans,
            })),
            ..Default::default()
        }]);
        let c = collect(&ch, 18.0);
        match &c.units[0] {
            Unit::Text { scale, text, .. } => {
                assert_eq!(text, "Title");
                assert!((scale - 1.5).abs() < f32::EPSILON);
            }
            _ => panic!("expected text"),
        }
    }

    #[test]
    fn layout_chapter_shapes_with_system_fonts() {
        let ch = chapter_with(vec![Block {
            kind: Some(block::Kind::Paragraph(paragraph("Hello world"))),
            ..Default::default()
        }]);
        let result = layout_chapter(
            &ch,
            LayoutParams {
                width: 400,
                height: 600,
                margin: 0.0,
                font_size: 18.0,
                line_height: 28.0,
                paragraph_spacing: 8.0,
                first_page_inset: 0.0,
                font_path: String::new(),
            },
        )
        .expect("layout");
        assert!(!result.pages.is_empty());
        assert!(result
            .pages[0]
            .lines
            .iter()
            .any(|l| !l.glyphs.is_empty()));
    }

    #[test]
    fn utf8_to_utf16_skips_multibyte_punctuation() {
        let s = "a\u{2019}b"; // a ’ b
        assert_eq!(s.len(), 5);
        assert_eq!(utf16_len(s), 3);
        assert_eq!(utf8_to_utf16(s, 0), 0);
        assert_eq!(utf8_to_utf16(s, 1), 1);
        assert_eq!(utf8_to_utf16(s, 4), 2);
        assert_eq!(utf8_to_utf16(s, 5), 3);
    }

    #[test]
    fn collect_start_is_utf16_after_curly_quote() {
        let ch = chapter_with(vec![
            Block {
                kind: Some(block::Kind::Paragraph(paragraph("It\u{2019}s"))),
                ..Default::default()
            },
            Block {
                kind: Some(block::Kind::Paragraph(paragraph("Hi"))),
                ..Default::default()
            },
        ]);
        let c = collect(&ch, 18.0);
        assert_eq!(c.plain, "It\u{2019}s\n\nHi");
        assert_eq!(c.plain.len(), 10); // 6-byte first word + 2 + 2
        assert_eq!(utf16_len(&c.plain), 8);
        match &c.units[1] {
            Unit::Text { start, text, .. } => {
                assert_eq!(text, "Hi");
                assert_eq!(*start, 6); // 4 utf16 + \n\n, not 8 utf-8 bytes
            }
            _ => panic!("expected second text unit"),
        }
    }

    #[test]
    fn layout_offsets_match_dart_utf16() {
        let text = "It\u{2019}s";
        assert_eq!(text.len(), 6);
        assert_eq!(utf16_len(text), 4);
        let ch = chapter_with(vec![Block {
            kind: Some(block::Kind::Paragraph(paragraph(text))),
            ..Default::default()
        }]);
        let result = layout_chapter(
            &ch,
            LayoutParams {
                width: 400,
                height: 600,
                margin: 0.0,
                font_size: 18.0,
                line_height: 28.0,
                paragraph_spacing: 8.0,
                first_page_inset: 0.0,
                font_path: String::new(),
            },
        )
        .expect("layout");
        assert_eq!(result.plain_text, text);
        let line = result.pages[0]
            .lines
            .iter()
            .find(|l| !l.glyphs.is_empty())
            .expect("shaped line");
        assert_eq!(line.char_start, 0);
        assert_eq!(line.char_end, 4);
    }
}
