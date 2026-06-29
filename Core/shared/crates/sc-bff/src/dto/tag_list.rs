//! Парсер SC `tag_list`: теги через пробел, многословные — в двойных кавычках
//! (`phonk "drum and bass" trap`). Пустая строка → `[]`.

pub(crate) fn parse_tag_list(raw: &str) -> Vec<String> {
    let mut tags = Vec::new();
    let mut current = String::new();
    let mut in_quotes = false;

    for ch in raw.chars() {
        match ch {
            '"' => in_quotes = !in_quotes,
            c if c.is_whitespace() && !in_quotes => push_tag(&mut tags, &mut current),
            c => current.push(c),
        }
    }
    push_tag(&mut tags, &mut current);
    tags
}

fn push_tag(tags: &mut Vec<String>, current: &mut String) {
    let trimmed = current.trim();
    if !trimmed.is_empty() {
        tags.push(trimmed.to_owned());
    }
    current.clear();
}

#[cfg(test)]
mod tests {
    use super::parse_tag_list;

    #[test]
    fn empty() {
        assert!(parse_tag_list("").is_empty());
        assert!(parse_tag_list("   ").is_empty());
    }

    #[test]
    fn single_and_multi_word_quoted() {
        assert_eq!(parse_tag_list("phonk"), vec!["phonk"]);
        assert_eq!(
            parse_tag_list(r#"phonk "drum and bass" trap"#),
            vec!["phonk", "drum and bass", "trap"]
        );
    }

    #[test]
    fn quoted_only() {
        assert_eq!(parse_tag_list(r#""phonk""#), vec!["phonk"]);
    }
}
