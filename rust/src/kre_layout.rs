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
//! Flutter still paints; these boxes are the hit-test / page-break source.

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

#[derive(Clone, Copy, Debug)]
pub struct LayoutParams {
    pub width: u32,
    pub height: u32,
    pub margin: f32,
    pub font_size: f32,
    pub line_height: f32,
    pub paragraph_spacing: f32,
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
    FS.get_or_init(|| Mutex::new(FontSystem::new()))
        .lock()
        .expect("font system")
}

/// Lay out one KIR chapter into page-sized glyph boxes.
pub fn layout_chapter(chapter: &Chapter, params: LayoutParams) -> LayoutResult {
    let collected = collect(chapter, params.font_size);
    let mut fs = font_system();
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
                let h = *height;
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

    let pages = paginate(lines, params.height as f32, params.margin);
    LayoutResult {
        plain_text: collected.plain,
        pages,
    }
}

/// Pixel → character offset on one page. `None` if the point misses every line.
#[allow(dead_code)] // mirrored in Dart `hitTestLayoutPage` until FRB wires it
pub fn hit_test(page: &LayoutPage, x: f32, y: f32) -> Option<u32> {
    for line in &page.lines {
        if y < line.y || y >= line.y + line.height {
            continue;
        }
        for g in &line.glyphs {
            if x >= g.x && x < g.x + g.width {
                return Some(g.char_start);
            }
        }
        if !line.glyphs.is_empty() {
            return Some(line.char_start);
        }
    }
    None
}

pub fn paginate(lines: Vec<LayoutLine>, page_height: f32, margin: f32) -> Vec<LayoutPage> {
    if lines.is_empty() {
        return vec![LayoutPage {
            char_start: 0,
            char_end: 0,
            lines: Vec::new(),
        }];
    }
    let usable = (page_height - 2.0 * margin).max(margin);
    let mut pages = Vec::new();
    let mut current: Vec<LayoutLine> = Vec::new();
    let mut origin = lines[0].y;

    for line in lines {
        let depth = line.y + line.height - origin;
        if depth > usable && !current.is_empty() {
            pages.push(rebase_page(std::mem::take(&mut current), origin, margin));
            origin = line.y;
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
                char_start: base + glyph.start as u32,
                char_end: base + glyph.end as u32,
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
    let start = c.plain.len();
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
        let pages = paginate(vec![line(10.0, 0), line(30.0, 1)], 50.0, 10.0);
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
}
