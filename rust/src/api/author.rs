/// Resolve the author to store for a book.
///
/// - If the caller provided no author, use the engine author.
/// - If both are present and match (case-insensitive, trimmed), keep the
///   engine author (canonical form from the source).
/// - On mismatch, prefer the engine author.
pub fn resolve_author(input: Option<&str>, engine: Option<&str>) -> Option<String> {
    let input = normalize(input);
    let engine = normalize(engine);

    match (input, engine) {
        (None, eng) => eng,
        (Some(_), Some(eng)) => Some(eng),
        (Some(inp), None) => Some(inp),
    }
}

fn normalize(value: Option<&str>) -> Option<String> {
    value
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
}

/// Lowercased / whitespace-collapsed form for comparisons.
pub fn author_key(value: &str) -> String {
    value
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

/// Score how well a candidate title/author matches the query (higher is better).
pub fn match_score(
    query_title: &str,
    query_author: Option<&str>,
    candidate_title: &str,
    candidate_authors: &[String],
) -> i32 {
    let qt = author_key(query_title);
    let ct = author_key(candidate_title);
    let mut score = 0;

    if qt == ct {
        score += 100;
    } else if ct.contains(&qt) || qt.contains(&ct) {
        score += 60;
    } else {
        // Token overlap
        let q_tokens: Vec<&str> = qt.split_whitespace().collect();
        let c_tokens: Vec<&str> = ct.split_whitespace().collect();
        let overlap = q_tokens
            .iter()
            .filter(|t| c_tokens.iter().any(|c| c == *t))
            .count();
        if overlap == 0 {
            return 0;
        }
        score += (overlap as i32) * 15;
    }

    if let Some(qa) = query_author.map(str::trim).filter(|s| !s.is_empty()) {
        let key = author_key(qa);
        if candidate_authors
            .iter()
            .any(|a| author_key(a) == key || author_key(a).contains(&key) || key.contains(&author_key(a)))
        {
            score += 40;
        } else if !candidate_authors.is_empty() {
            score -= 20;
        }
    }

    score
}

/// True when OL/GB result is too sparse and we should try the fallback.
pub fn needs_fallback(author: &Option<String>, cover_url: &Option<String>, genres: &[String]) -> bool {
    author.is_none() && cover_url.is_none() && genres.is_empty()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolve_uses_engine_when_input_empty() {
        assert_eq!(
            resolve_author(None, Some("Alice")),
            Some("Alice".into())
        );
        assert_eq!(
            resolve_author(Some("  "), Some("Alice")),
            Some("Alice".into())
        );
    }

    #[test]
    fn resolve_prefers_engine_on_mismatch() {
        assert_eq!(
            resolve_author(Some("Bob"), Some("Alice")),
            Some("Alice".into())
        );
    }

    #[test]
    fn resolve_keeps_engine_on_case_insensitive_match() {
        assert_eq!(
            resolve_author(Some("alice"), Some("Alice")),
            Some("Alice".into())
        );
    }

    #[test]
    fn resolve_keeps_input_when_engine_missing() {
        assert_eq!(
            resolve_author(Some("Bob"), None),
            Some("Bob".into())
        );
    }

    #[test]
    fn match_score_exact_title_and_author() {
        let score = match_score(
            "The Hobbit",
            Some("J. R. R. Tolkien"),
            "The Hobbit",
            &["J. R. R. Tolkien".into()],
        );
        assert!(score >= 140);
    }

    #[test]
    fn match_score_zero_when_unrelated() {
        let score = match_score(
            "The Hobbit",
            None,
            "Dune",
            &["Frank Herbert".into()],
        );
        assert_eq!(score, 0);
    }

    #[test]
    fn needs_fallback_when_empty() {
        assert!(needs_fallback(&None, &None, &[]));
        assert!(!needs_fallback(&Some("A".into()), &None, &[]));
    }
}
