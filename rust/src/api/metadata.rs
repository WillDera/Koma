use futures::future::BoxFuture;
use futures::stream::{FuturesUnordered, StreamExt};
use std::sync::Arc;

use super::author::{needs_fallback, resolve_author};
use super::{google_books, open_library};

/// One book to look up. [id] is the Isar book id and is echoed in the result.
#[derive(Clone, Debug)]
pub struct BookLookupQuery {
    pub id: i64,
    pub title: String,
    pub author: Option<String>,
}

/// Structured metadata for a single book, keyed by the input [id].
#[derive(Clone, Debug)]
pub struct BookMetadataResult {
    pub id: i64,
    pub title: String,
    pub author: Option<String>,
    pub cover_url: Option<String>,
    pub genres: Vec<String>,
    pub release_date: Option<String>,
    /// `"open_library"` or `"google_books"` when found; empty when not.
    pub source: String,
    pub remote_id: Option<String>,
    pub found: bool,
    pub error: Option<String>,
}

/// Look up metadata for many books. Open Library is primary; Google Books is
/// used when OL misses or returns an empty author+cover+genres set.
pub async fn lookup_books(
    queries: Vec<BookLookupQuery>,
    google_api_key: Option<String>,
) -> Vec<BookMetadataResult> {
    if queries.is_empty() {
        return Vec::new();
    }

    let client = match reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(20))
        .build()
    {
        Ok(c) => Arc::new(c),
        Err(e) => {
            return queries
                .into_iter()
                .map(|q| BookMetadataResult {
                    id: q.id,
                    title: q.title,
                    author: q.author,
                    cover_url: None,
                    genres: vec![],
                    release_date: None,
                    source: String::new(),
                    remote_id: None,
                    found: false,
                    error: Some(format!("http client: {e}")),
                })
                .collect();
        }
    };

    let key = google_api_key;
    let mut results = Vec::with_capacity(queries.len());
    // Preserve order by collecting into a map keyed by id, then emit in input order.
    let order: Vec<i64> = queries.iter().map(|q| q.id).collect();
    let mut by_id = std::collections::HashMap::new();

    let mut in_flight: FuturesUnordered<BoxFuture<'static, BookMetadataResult>> =
        FuturesUnordered::new();
    const MAX_CONCURRENCY: usize = 3;

    let mut iter = queries.into_iter();

    for _ in 0..MAX_CONCURRENCY {
        if let Some(q) = iter.next() {
            let c = Arc::clone(&client);
            let k = key.clone();
            in_flight.push(Box::pin(async move { lookup_one(c, q, k).await }));
        }
    }

    while let Some(res) = in_flight.next().await {
        by_id.insert(res.id, res);
        if let Some(q) = iter.next() {
            let c = Arc::clone(&client);
            let k = key.clone();
            in_flight.push(Box::pin(async move { lookup_one(c, q, k).await }));
        }
    }

    for id in order {
        if let Some(r) = by_id.remove(&id) {
            results.push(r);
        }
    }
    results
}

async fn lookup_one(
    client: Arc<reqwest::Client>,
    query: BookLookupQuery,
    google_api_key: Option<String>,
) -> BookMetadataResult {
    let input_author = query.author.clone();
    let title = query.title.trim().to_string();
    if title.is_empty() {
        return BookMetadataResult {
            id: query.id,
            title: query.title,
            author: input_author,
            cover_url: None,
            genres: vec![],
            release_date: None,
            source: String::new(),
            remote_id: None,
            found: false,
            error: Some("empty title".into()),
        };
    }

    let author_ref = input_author.as_deref();

    match open_library::lookup(&client, &title, author_ref).await {
        Ok(Some(hit)) => {
            let author = resolve_author(author_ref, hit.author.as_deref());
            let cover_url = hit.cover_url;
            let genres = hit.genres;
            let release_date = hit.release_date;
            let remote_id = hit.remote_id;
            let result_title = hit.title;

            if needs_fallback(&author, &cover_url, &genres) {
                if let Ok(Some(gb)) =
                    google_books::lookup(&client, &title, author_ref, google_api_key.as_deref())
                        .await
                {
                    return BookMetadataResult {
                        id: query.id,
                        title: gb.title,
                        author: resolve_author(author_ref, gb.author.as_deref()),
                        cover_url: gb.cover_url.or(cover_url),
                        genres: if gb.genres.is_empty() { genres } else { gb.genres },
                        release_date: gb.release_date.or(release_date),
                        source: "google_books".into(),
                        remote_id: gb.remote_id.or(remote_id),
                        found: true,
                        error: None,
                    };
                }
            }

            return BookMetadataResult {
                id: query.id,
                title: result_title,
                author,
                cover_url,
                genres,
                release_date,
                source: "open_library".into(),
                remote_id,
                found: true,
                error: None,
            };
        }
        Ok(None) => {
            // Fall through to Google Books.
        }
        Err(e) => {
            // Try Google Books even if OL errored; keep OL error if GB also fails.
            match google_books::lookup(&client, &title, author_ref, google_api_key.as_deref())
                .await
            {
                Ok(Some(gb)) => {
                    return BookMetadataResult {
                        id: query.id,
                        title: gb.title,
                        author: resolve_author(author_ref, gb.author.as_deref()),
                        cover_url: gb.cover_url,
                        genres: gb.genres,
                        release_date: gb.release_date,
                        source: "google_books".into(),
                        remote_id: gb.remote_id,
                        found: true,
                        error: None,
                    };
                }
                Ok(None) => {
                    return BookMetadataResult {
                        id: query.id,
                        title: query.title,
                        author: input_author,
                        cover_url: None,
                        genres: vec![],
                        release_date: None,
                        source: String::new(),
                        remote_id: None,
                        found: false,
                        error: Some(format!("open_library: {e}")),
                    };
                }
                Err(ge) => {
                    return BookMetadataResult {
                        id: query.id,
                        title: query.title,
                        author: input_author,
                        cover_url: None,
                        genres: vec![],
                        release_date: None,
                        source: String::new(),
                        remote_id: None,
                        found: false,
                        error: Some(format!("open_library: {e}; google_books: {ge}")),
                    };
                }
            }
        }
    }

    // OL miss → Google Books
    match google_books::lookup(&client, &title, author_ref, google_api_key.as_deref()).await {
        Ok(Some(gb)) => BookMetadataResult {
            id: query.id,
            title: gb.title,
            author: resolve_author(author_ref, gb.author.as_deref()),
            cover_url: gb.cover_url,
            genres: gb.genres,
            release_date: gb.release_date,
            source: "google_books".into(),
            remote_id: gb.remote_id,
            found: true,
            error: None,
        },
        Ok(None) => BookMetadataResult {
            id: query.id,
            title: query.title,
            author: input_author,
            cover_url: None,
            genres: vec![],
            release_date: None,
            source: String::new(),
            remote_id: None,
            found: false,
            error: None,
        },
        Err(e) => BookMetadataResult {
            id: query.id,
            title: query.title,
            author: input_author,
            cover_url: None,
            genres: vec![],
            release_date: None,
            source: String::new(),
            remote_id: None,
            found: false,
            error: Some(e),
        },
    }
}
