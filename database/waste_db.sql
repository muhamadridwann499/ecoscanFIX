-- =============================================
-- Database: waste_classifier
-- EcoScan — Sistem Klasifikasi Sampah CNN
-- =============================================

CREATE DATABASE IF NOT EXISTS waste_classifier
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE waste_classifier;

-- ── USERS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    username     VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email        VARCHAR(100),
    full_name    VARCHAR(100),
    role         ENUM('admin','user') DEFAULT 'user',
    is_active    BOOLEAN DEFAULT TRUE,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login   TIMESTAMP NULL
);

-- ── CLASSIFICATIONS ───────────────────────────
CREATE TABLE IF NOT EXISTS classifications (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    user_id           INT NULL,
    image_filename    VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255),
    predicted_class   VARCHAR(50) NOT NULL,
    confidence        FLOAT NOT NULL,
    probabilities     JSON,
    processing_time   FLOAT,
    ip_address        VARCHAR(45),
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ── WASTE CATEGORIES ──────────────────────────
CREATE TABLE IF NOT EXISTS waste_categories (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(50) NOT NULL UNIQUE,
    label          VARCHAR(50) NOT NULL,
    description    TEXT,
    recycling_tips TEXT,
    color_code     VARCHAR(10) DEFAULT '#00ff88',
    icon           VARCHAR(50),
    is_recyclable  BOOLEAN DEFAULT TRUE,
    updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ── UMKM GALLERY (foto hasil UMKM oleh admin) ─
CREATE TABLE IF NOT EXISTS umkm_gallery (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    title          VARCHAR(150) NOT NULL,
    waste_type     VARCHAR(50),
    image_filename VARCHAR(255) NOT NULL,
    description    TEXT,
    created_by     INT NULL,
    is_active      BOOLEAN DEFAULT TRUE,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- ── MODEL VERSIONS ────────────────────────────
CREATE TABLE IF NOT EXISTS model_versions (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    version      VARCHAR(20) NOT NULL,
    architecture VARCHAR(100),
    accuracy     FLOAT,
    val_accuracy FLOAT,
    total_epochs INT,
    dataset_size INT,
    notes        TEXT,
    is_active    BOOLEAN DEFAULT FALSE,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ── DAILY STATS ───────────────────────────────
CREATE TABLE IF NOT EXISTS daily_stats (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    stat_date             DATE NOT NULL UNIQUE,
    total_classifications INT DEFAULT 0,
    cardboard_count       INT DEFAULT 0,
    glass_count           INT DEFAULT 0,
    metal_count           INT DEFAULT 0,
    paper_count           INT DEFAULT 0,
    plastic_count         INT DEFAULT 0,
    trash_count           INT DEFAULT 0,
    avg_confidence        FLOAT DEFAULT 0,
    updated_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- =============================================
-- DEFAULT DATA
-- =============================================

INSERT INTO waste_categories (name,label,description,recycling_tips,color_code,icon,is_recyclable) VALUES
('cardboard','Kardus','Kardus dan karton bekas seperti kotak packaging, kotak sereal, dan karton gelombang.',
 'Ratakan kardus sebelum dibuang. Pastikan bersih dari minyak. Pisahkan dari lakban dan staples.','#F4A460','📦',TRUE),
('glass','Kaca','Botol kaca, toples, dan wadah kaca lainnya. Kaca dapat didaur ulang tanpa batas.',
 'Bilas botol sebelum daur ulang. Jangan campurkan kaca pecah dengan utuh. Pisahkan berdasarkan warna.','#87CEEB','🫙',TRUE),
('metal','Logam','Kaleng aluminium, kaleng baja, tutup botol, dan logam lainnya.',
 'Bilas kaleng sebelum daur ulang. Hancurkan kaleng untuk hemat ruang. Pisahkan aluminium dari baja.','#C0C0C0','🥫',TRUE),
('paper','Kertas','Kertas kantor, koran, majalah, dan kertas campuran.',
 'Simpan dalam kondisi kering. Pisahkan kertas glossy dari biasa. Jangan campur dengan kertas berminyak.','#DEB887','📄',TRUE),
('plastic','Plastik','Botol plastik, wadah makanan, dan plastik keras lainnya.',
 'Periksa kode daur ulang (1-7). Bilas wadah dari sisa makanan. Lepas tutup jika berbeda material.','#FF6B6B','♻️',TRUE),
('trash','Sampah Umum','Sampah tidak dapat didaur ulang seperti styrofoam, popok, dan plastik campuran.',
 'Kurangi penggunaan produk ini. Pilih alternatif yang dapat didaur ulang. Buang di tempat sampah residu.','#808080','🗑️',FALSE)
ON DUPLICATE KEY UPDATE label=VALUES(label);

-- Admin default (password: admin123)
INSERT INTO users (username,password_hash,email,full_name,role) VALUES
('admin','$2b$12$jjBDK442D73tBNlVGZAT8efc7Neqfm0THArsoiZh6rwOGqS68yGQy','admin@ecoscan.id','Administrator','admin')
ON DUPLICATE KEY UPDATE role='admin', password_hash='$2b$12$jjBDK442D73tBNlVGZAT8efc7Neqfm0THArsoiZh6rwOGqS68yGQy';

INSERT INTO model_versions (version,architecture,accuracy,val_accuracy,total_epochs,dataset_size,notes,is_active) VALUES
('v1.0','MobileNetV2 Transfer Learning',NULL,NULL,0,2533,'Initial — train dengan train_model.py',TRUE)
ON DUPLICATE KEY UPDATE version=version;

-- =============================================
-- VIEWS
-- =============================================

CREATE OR REPLACE VIEW v_classification_summary AS
SELECT predicted_class,
       COUNT(*) as total,
       ROUND(AVG(confidence)*100,2) as avg_confidence_pct,
       ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM classifications),2) as percentage
FROM classifications GROUP BY predicted_class ORDER BY total DESC;

CREATE OR REPLACE VIEW v_recent_classifications AS
SELECT c.id, c.image_filename, c.original_filename, c.predicted_class,
       ROUND(c.confidence*100,2) as confidence_pct, c.created_at,
       wc.description, wc.recycling_tips, wc.color_code, wc.icon, wc.is_recyclable,
       u.username, u.full_name
FROM classifications c
LEFT JOIN waste_categories wc ON c.predicted_class = wc.name
LEFT JOIN users u ON c.user_id = u.id
ORDER BY c.created_at DESC LIMIT 100;

CREATE OR REPLACE VIEW v_user_stats AS
SELECT u.id, u.username, u.full_name, u.email, u.role, u.is_active,
       u.created_at, u.last_login,
       COUNT(c.id) as total_classifications,
       ROUND(AVG(c.confidence)*100,2) as avg_confidence,
       MAX(c.created_at) as last_activity
FROM users u
LEFT JOIN classifications c ON u.id = c.user_id
GROUP BY u.id;

