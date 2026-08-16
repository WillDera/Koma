use serde::Deserialize;

use super::author::match_score;
use super::http_util;

#[derive(Debug, Clone, Default)]
pub struct GbHit {
    pub title: String,
    pub author: Option<String>,
    pub cover_url: Option<String>,
    pub genres: Vec<String>,
    pub release_date: Option<String>,
    pub remote_id: Option<String>,
}

#[derive(Debug, Deserialize)]
struct VolumesResponse {
    items: Option<Vec<VolumeItem>>,
}

#[derive(Debug, Deserialize)]
struct VolumeItem {
    id: Option<String>,
    #[serde(rename = "volumeInfo")]
    volume_info: Option<VolumeInfo>,
}

#[derive(Debug, Deserialize)]
struct VolumeInfo {
    title: Option<String>,
    authors: Option<Vec<String>>,
    categories: Option<Vec<String>>,
    #[serde(rename = "publishedDate")]
    published_date: Option<String>,
    #[serde(rename = "imageLinks")]
    image_links: Option<ImageLinks>,
}

#[derive(Debug, Deserialize)]
struct ImageLinks {
    thumbnail: Option<String>,
    small: Option<String>,
    medium: Option<String>,
    large: Option<String>,
}

pub async fn lookup(
    client: &reqwest::Client,
    title: &str,
    author: Option<&str>,
    api_key: Option<&str>,
) -> Result<Option<GbHit>, String> {
    // Anonymous Google Books quota is tiny; without a key we only burn 429s.
    let Some(key) = api_key.map(str::trim).filter(|s| !s.is_empty()) else {
        return Ok(None);
    };

    let mut q = format!("intitle:{}", title.trim());
    if let Some(a) = author.map(str::trim).filter(|s| !s.is_empty()) {
        q.push_str(&format!("+inauthor:{a}"));
    }

    let url = format!(
        "https://www.googleapis.com/books/v1/volumes?q={}&maxResults=8&key={}",
        urlencoding::encode(&q),
        urlencoding::encode(key)
    );

    let body: VolumesResponse = http_util::get_json(client, &url).await?;
    let items = body.items.unwrap_or_default();

    let mut best: Option<(i32, VolumeItem)> = None;
    for item in items {
        let info = match &item.volume_info {
            Some(v) => v,
            None => continue,
        };
        let cand_title = info.title.clone().unwrap_or_default();
        let authors = info.authors.clone().unwrap_or_default();
        let score = match_score(title, author, &cand_title, &authors);
        if score <= 0 {
            continue;
        }
        match &best {
            None => best = Some((score, item)),
            Some((s, _)) if score > *s => best = Some((score, item)),
            _ => {}
        }
    }

    let Some((_score, item)) = best else {
        return Ok(None);
    };
    let info = item.volume_info.unwrap_or(VolumeInfo {
        title: None,
        authors: None,
        categories: None,
        published_date: None,
        image_links: None,
    });

    let cover_url = info.image_links.and_then(|links| {
        links
            .large
            .or(links.medium)
            .or(links.small)
            .or(links.thumbnail)
            .map(|u| u.replace("http://", "https://"))
    });

    Ok(Some(GbHit {
        title: info.title.unwrap_or_else(|| title.to_string()),
        author: info.authors.and_then(|a| a.into_iter().next()),
        cover_url,
        genres: info.categories.unwrap_or_default(),
        release_date: normalize_date(info.published_date),
        remote_id: item.id,
    }))
}

fn normalize_date(raw: Option<String>) -> Option<String> {
    let raw = raw?.trim().to_string();
    if raw.is_empty() {
        return None;
    }
    if raw.len() >= 10 && raw.as_bytes().get(4) == Some(&b'-') {
        return Some(raw[..10].to_string());
    }
    if raw.len() == 4 && raw.chars().all(|c| c.is_ascii_digit()) {
        return Some(format!("{raw}-01-01"));
    }
    if raw.len() == 7 && raw.as_bytes().get(4) == Some(&b'-') {
        return Some(format!("{raw}-01"));
    }
    Some(raw)
}
