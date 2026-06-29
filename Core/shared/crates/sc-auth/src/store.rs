use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::RwLock;

use crate::{AuthError, Session};

/// Владелец сессии. В памяти — текущее состояние, на диске — атомарный снимок
/// (tmp → fsync → rename): либо старое, либо новое, никогда не рваное.
pub struct SessionStore {
    path: PathBuf,
    state: RwLock<Session>,
}

impl SessionStore {
    /// Загрузить из файла (или дефолт, если файла/битый нет).
    pub fn load(path: impl Into<PathBuf>) -> Self {
        let path = path.into();
        let state = read_session(&path).unwrap_or_default();
        Self {
            path,
            state: RwLock::new(state),
        }
    }

    pub fn session(&self) -> Session {
        self.read().clone()
    }

    pub fn is_authenticated(&self) -> bool {
        self.read().token.is_some()
    }

    pub fn token(&self) -> Option<String> {
        self.read().token.clone()
    }

    /// Новая сессия. Premium сбрасывается — переустановится при проверке подписки.
    pub fn set_session(&self, token: Option<String>) -> Result<(), AuthError> {
        {
            let mut state = self.write();
            state.token = token;
            state.premium = false;
        }
        self.persist()
    }

    pub fn set_premium(&self, premium: bool) -> Result<(), AuthError> {
        self.write().premium = premium;
        self.persist()
    }

    fn persist(&self) -> Result<(), AuthError> {
        let snapshot = self.read().clone();
        write_atomic(&self.path, &snapshot)
    }

    fn read(&self) -> std::sync::RwLockReadGuard<'_, Session> {
        // Poison не паникуем — восстанавливаем (см. правило no-unwrap в проде).
        self.state.read().unwrap_or_else(|poison| poison.into_inner())
    }

    fn write(&self) -> std::sync::RwLockWriteGuard<'_, Session> {
        self.state.write().unwrap_or_else(|poison| poison.into_inner())
    }
}

fn read_session(path: &Path) -> Option<Session> {
    let bytes = fs::read(path).ok()?;
    serde_json::from_slice(&bytes).ok()
}

fn write_atomic(path: &Path, session: &Session) -> Result<(), AuthError> {
    let json = serde_json::to_vec_pretty(session).map_err(|e| AuthError::Storage(e.to_string()))?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| AuthError::Storage(e.to_string()))?;
    }
    let tmp = path.with_extension("json.tmp");
    let mut file = fs::File::create(&tmp).map_err(|e| AuthError::Storage(e.to_string()))?;
    file.write_all(&json)
        .map_err(|e| AuthError::Storage(e.to_string()))?;
    file.sync_all().map_err(|e| AuthError::Storage(e.to_string()))?;
    fs::rename(&tmp, path).map_err(|e| AuthError::Storage(e.to_string()))?;
    Ok(())
}
