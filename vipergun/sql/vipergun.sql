-- ============================================================
-- VIPERGUN - Schema base de données
-- Importer une seule fois sur ton serveur MariaDB/MySQL
-- ============================================================

CREATE TABLE IF NOT EXISTS `vipergun_coffres` (
    `citizenid`    VARCHAR(50)  NOT NULL,
    `coffre_count` INT          NOT NULL DEFAULT 4,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `vipergun_weapon_overrides` (
    `weapon_name` VARCHAR(100) NOT NULL,
    `body_damage` INT          NOT NULL,
    `head_damage` INT          NOT NULL,
    `range_val`   FLOAT        NOT NULL,
    `enabled`     TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (`weapon_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `vipergun_ped_config` (
    `id`      INT          NOT NULL DEFAULT 1,
    `model`   VARCHAR(100) NOT NULL DEFAULT 's_m_y_dealer_01',
    `x`       FLOAT        NOT NULL DEFAULT 0.0,
    `y`       FLOAT        NOT NULL DEFAULT 0.0,
    `z`       FLOAT        NOT NULL DEFAULT 0.0,
    `heading` FLOAT        NOT NULL DEFAULT 0.0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `vipergun_ped_config` (`id`) VALUES (1);
