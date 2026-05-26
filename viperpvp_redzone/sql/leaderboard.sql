CREATE TABLE IF NOT EXISTS `redzone_stats` (
  `id`           INT(11)      NOT NULL AUTO_INCREMENT,
  `citizenid`    VARCHAR(50)  NOT NULL,
  `player_name`  VARCHAR(100) NOT NULL DEFAULT 'Inconnu',
  `kills_total`  INT(11)      NOT NULL DEFAULT 0,
  `deaths_total` INT(11)      NOT NULL DEFAULT 0,
  `kills_month`  INT(11)      NOT NULL DEFAULT 0,
  `updated_at`   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
