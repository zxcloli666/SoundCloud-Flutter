use serde::{Deserialize, Serialize};

/// Страница списка из BFF (`{collection, page, page_size, has_more}`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ListPage<T> {
    pub items: Vec<T>,
    pub page: u32,
    pub page_size: u32,
    pub has_more: bool,
}

impl<T> ListPage<T> {
    pub fn new(items: Vec<T>, page: u32, page_size: u32, has_more: bool) -> Self {
        Self {
            items,
            page,
            page_size,
            has_more,
        }
    }

    pub fn map<U>(self, f: impl Fn(T) -> U) -> ListPage<U> {
        ListPage {
            items: self.items.into_iter().map(f).collect(),
            page: self.page,
            page_size: self.page_size,
            has_more: self.has_more,
        }
    }
}

/// Курсорная страница каталога (`{items, next_cursor}`). `next_cursor=None` —
/// последняя страница.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CursorPage<T> {
    pub items: Vec<T>,
    pub next_cursor: Option<String>,
}

impl<T> CursorPage<T> {
    pub fn new(items: Vec<T>, next_cursor: Option<String>) -> Self {
        Self { items, next_cursor }
    }
}
