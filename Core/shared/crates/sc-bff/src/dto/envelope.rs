use serde::Deserialize;

use sc_domain::ListPage;

/// Стандартный конверт списка BFF. `has_more` опционален (часть вариантов
/// его не возвращает, напр. `/artists/{id}/tracks`).
#[derive(Deserialize)]
pub(crate) struct ListEnvelope<T> {
    pub collection: Vec<T>,
    #[serde(default)]
    pub page: u32,
    #[serde(default)]
    pub page_size: u32,
    #[serde(default)]
    pub has_more: bool,
}

impl<T> ListEnvelope<T> {
    /// Свернуть в доменную страницу, конвертируя каждый элемент.
    pub(crate) fn into_page<D>(self, map: impl Fn(T) -> D) -> ListPage<D> {
        let has_more = self.has_more;
        let page = self.page;
        let page_size = if self.page_size == 0 {
            self.collection.len() as u32
        } else {
            self.page_size
        };
        ListPage::new(self.collection.into_iter().map(map).collect(), page, page_size, has_more)
    }
}

/// Конверт каталога (`/discover/*`): `{items, next_cursor}`. Курсорная
/// пагинация — `next_cursor` ведёт на следующую страницу (None = конец).
#[derive(Deserialize)]
pub(crate) struct ItemsEnvelope<T> {
    #[serde(default = "Vec::new")]
    pub items: Vec<T>,
    #[serde(default)]
    pub next_cursor: Option<String>,
}
