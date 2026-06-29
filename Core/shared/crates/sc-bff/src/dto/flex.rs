//! Бэкенд непоследователен с id: то число (`233409064`), то строка
//! (`"182689078"` в `popular_tracks.user.id`). Принимаем обе формы.

use serde::{Deserialize, Deserializer};

#[derive(Deserialize)]
#[serde(untagged)]
enum NumOrStr {
    Num(i64),
    Str(String),
}

/// `i64` из числа или строки. Нечисловая строка → ошибка декода.
pub(crate) fn de_i64<'de, D>(de: D) -> Result<i64, D::Error>
where
    D: Deserializer<'de>,
{
    match NumOrStr::deserialize(de)? {
        NumOrStr::Num(n) => Ok(n),
        NumOrStr::Str(s) => s.parse::<i64>().map_err(serde::de::Error::custom),
    }
}
