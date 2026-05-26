CREATE TABLE IF NOT EXISTS `redzone_zones` (
  `id`             INT(11)      NOT NULL AUTO_INCREMENT,
  `name`           VARCHAR(100) NOT NULL,
  `x`              FLOAT        NOT NULL,
  `y`              FLOAT        NOT NULL,
  `z`              FLOAT        NOT NULL,
  `radius`         FLOAT        NOT NULL DEFAULT 150.0,
  `active`         TINYINT(1)   NOT NULL DEFAULT 0,
  `kill_count`     INT(11)      NOT NULL DEFAULT 0,
  `kill_threshold` INT(11)      NOT NULL DEFAULT 20,
  `money_reward`   INT(11)      NOT NULL DEFAULT 200,
  `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
