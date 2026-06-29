//! Оффлайн-кэш рантайма: интроспекция и управление материализованными m4a.
//! Тонкие пасс-тру к [`sc_cache::TrackCache`].

use sc_cache::LikesProgress;
use sc_domain::{CacheEntry, Urn};

use crate::{CoreError, ScRuntime};

impl ScRuntime {
    pub fn cache_inventory(&self) -> Result<Vec<CacheEntry>, CoreError> {
        Ok(self.cache().inventory()?)
    }

    pub fn cache_total_bytes(&self) -> Result<i64, CoreError> {
        Ok(self.cache().total_bytes()?)
    }

    pub fn cache_is_cached(&self, urn: &Urn) -> bool {
        self.cache().is_cached(urn)
    }

    pub async fn cache_remove(&self, urn: &Urn) -> Result<(), CoreError> {
        Ok(self.cache().remove(urn).await?)
    }

    /// Форсировать скачивание+транскод трека сейчас (прогрев оффлайна). Прогресс
    /// не транслируем — это фоновый прогрев, не текущее воспроизведение.
    pub async fn cache_ensure(&self, urn: &Urn) -> Result<(), CoreError> {
        self.cache().ensure(urn, None).await?;
        Ok(())
    }

    /// Размер защищённого кэша лайков (байты).
    pub fn cache_liked_bytes(&self) -> Result<i64, CoreError> {
        Ok(self.cache().liked_bytes()?)
    }

    /// Очистить обычный кэш (защищённый кэш лайков не трогаем).
    pub fn cache_clear(&self) -> Result<(), CoreError> {
        Ok(self.cache().clear()?)
    }

    /// Очистить защищённый кэш лайков.
    pub fn cache_clear_liked(&self) -> Result<(), CoreError> {
        Ok(self.cache().clear_liked()?)
    }

    /// Применить лимит обычного аудиокэша (LRU-вытеснение). Зовётся фронтом после
    /// скачки трека (источник лимита — настройки), как в легаси `audio.ts`.
    pub fn cache_enforce_limit(&self, limit_mb: u64) {
        self.cache().enforce_limit(limit_mb);
    }

    pub fn cache_likes_running(&self) -> bool {
        self.cache().cache_likes_running()
    }

    pub fn cancel_cache_likes(&self) {
        self.cache().cancel_cache_likes();
    }

    /// Экспорт трека в файл (легаси `save_track_to_path`): гарантируем кэш
    /// (валидный m4a) и копируем в [`dest`]. Метаданные уже зашиты в исходный m4a.
    /// Путь назначения даёт платформа (диалог сохранения) — Rust только копирует.
    pub async fn export_track(&self, urn: &Urn, dest: &str) -> Result<(), CoreError> {
        let m4a = self.cache().ensure(urn, None).await?;
        tokio::fs::copy(m4a.path(), dest)
            .await
            .map_err(|e| CoreError::Init(format!("export copy: {e}")))?;
        Ok(())
    }

    /// Опережающий прогрев трека в фоне (легаси `track_preload`): кэшируем, НЕ
    /// играя. Fire-and-forget — ошибки глушим (спекулятивный прогрев очереди).
    pub fn preload_track(&self, urn: Urn) {
        let rt = self.clone();
        tokio::spawn(async move {
            let _ = rt.cache().ensure(&urn, None).await;
        });
    }

    /// Bulk-кэш лайков в защищённый кэш с трансляцией прогресса в [`likes_progress`].
    pub async fn cache_likes(&self, urns: Vec<Urn>) -> Result<(), CoreError> {
        let tx = self.likes_progress_tx();
        let report = move |progress: LikesProgress| {
            let _ = tx.send(progress);
        };
        self.cache().cache_likes(urns, &report).await?;
        Ok(())
    }
}
