CREATE TABLE IF NOT EXISTS `ft_admins` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `license` longtext NOT NULL,
  `name` varchar(100) NOT NULL DEFAULT 'Unknown',
  `permissions` JSON NOT NULL DEFAULT ('{}'),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `license_unique` (`license`(255))
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE IF NOT EXISTS `ft_admin_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `license` longtext NOT NULL,
  `data` longtext NOT NULL DEFAULT '[]',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE IF NOT EXISTS `ft_admin_bans` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name1` VARCHAR(50) NOT NULL,     
  `name2` VARCHAR(50) NOT NULL,      
  `license` VARCHAR(50) NOT NULL,   
  `admin` VARCHAR(50) NOT NULL,    
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
