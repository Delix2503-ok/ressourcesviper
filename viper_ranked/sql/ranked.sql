CREATE TABLE IF NOT EXISTS `ranked_stats` (
    `citizenid`  VARCHAR(50)  NOT NULL,
    `name`       VARCHAR(100) DEFAULT NULL,
    `wins`       INT(11)      DEFAULT 0,
    `losses`     INT(11)      DEFAULT 0,
    `elo`        INT(11)      DEFAULT 1000,
    `matches`    INT(11)      DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
