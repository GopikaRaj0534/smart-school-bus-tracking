SET FOREIGN_KEY_CHECKS = 0;

-- 1. users
CREATE TABLE IF NOT EXISTS `users` (
  `user_id` int(11) NOT NULL AUTO_INCREMENT,
  `full_name` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `phone` varchar(15) DEFAULT NULL,
  `license_number` varchar(50) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('Admin','Driver','Parent') NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` varchar(20) NOT NULL DEFAULT 'APPROVED',
  `rejection_reason` text DEFAULT NULL,
  `account_status` varchar(20) NOT NULL DEFAULT 'APPROVED',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Default Admin User (admin@gmail.com / admin123)
INSERT IGNORE INTO `users` (`user_id`, `full_name`, `email`, `phone`, `license_number`, `password`, `role`, `created_at`, `status`, `rejection_reason`, `account_status`) VALUES
(4, 'Admin', 'admin@gmail.com', '7890766754', NULL, 'scrypt:32768:8:1$Iw2qTbtdoBGRiV0T$f3d8d89a74e9e4ef3c349e91170639dc4fcb7ad2ffdf2506e66a716df7171423ed63bad08c4eace3e152001a1fb5c9c3d966dda68f59f7d1f2954431d4f83673', 'Admin', '2026-07-26 22:08:51', 'APPROVED', NULL, 'APPROVED');

-- 2. routes
CREATE TABLE IF NOT EXISTS `routes` (
  `route_id` int(11) NOT NULL AUTO_INCREMENT,
  `route_name` varchar(100) NOT NULL,
  PRIMARY KEY (`route_id`),
  UNIQUE KEY `route_name` (`route_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 3. pickup_stops
CREATE TABLE IF NOT EXISTS `pickup_stops` (
  `stop_id` int(11) NOT NULL AUTO_INCREMENT,
  `route_id` int(11) NOT NULL,
  `stop_name` varchar(100) NOT NULL,
  `stop_order` int(11) DEFAULT 1,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  PRIMARY KEY (`stop_id`),
  KEY `route_id` (`route_id`),
  CONSTRAINT `pickup_stops_ibfk_1` FOREIGN KEY (`route_id`) REFERENCES `routes` (`route_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4. buses
CREATE TABLE IF NOT EXISTS `buses` (
  `bus_id` int(11) NOT NULL AUTO_INCREMENT,
  `bus_number` varchar(50) NOT NULL,
  `registration_number` varchar(50) DEFAULT NULL,
  `route` varchar(150) NOT NULL,
  `driver_name` varchar(100) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'Active',
  `start_point` varchar(100) DEFAULT NULL,
  `destination` varchar(100) DEFAULT NULL,
  `driver_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`bus_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 5. parent_children
CREATE TABLE IF NOT EXISTS `parent_children` (
  `child_id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) NOT NULL,
  `child_name` varchar(100) NOT NULL,
  `bus_id` int(11) DEFAULT NULL,
  `route_id` int(11) DEFAULT NULL,
  `pickup_stop_id` int(11) DEFAULT NULL,
  `class_name` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`child_id`),
  KEY `parent_id` (`parent_id`),
  KEY `fk_child_bus` (`bus_id`),
  KEY `fk_child_route` (`route_id`),
  CONSTRAINT `fk_child_bus` FOREIGN KEY (`bus_id`) REFERENCES `buses` (`bus_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_child_route` FOREIGN KEY (`route_id`) REFERENCES `routes` (`route_id`) ON DELETE SET NULL,
  CONSTRAINT `parent_children_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 6. student_boarding
CREATE TABLE IF NOT EXISTS `student_boarding` (
  `attendance_id` int(11) NOT NULL AUTO_INCREMENT,
  `child_id` int(11) NOT NULL,
  `bus_id` int(11) NOT NULL,
  `driver_id` int(11) NOT NULL,
  `trip_id` int(11) DEFAULT NULL,
  `attendance_date` date NOT NULL,
  `boarding_status` enum('Not Boarded','Boarded','Dropped Off') DEFAULT 'Not Boarded',
  `boarding_time` time DEFAULT NULL,
  `drop_off_status` enum('Pending','Dropped Off') DEFAULT 'Pending',
  `drop_off_time` time DEFAULT NULL,
  `stop_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`attendance_id`),
  UNIQUE KEY `unique_daily_child` (`child_id`,`attendance_date`,`bus_id`),
  KEY `bus_id` (`bus_id`),
  KEY `driver_id` (`driver_id`),
  CONSTRAINT `student_boarding_ibfk_1` FOREIGN KEY (`child_id`) REFERENCES `parent_children` (`child_id`) ON DELETE CASCADE,
  CONSTRAINT `student_boarding_ibfk_2` FOREIGN KEY (`bus_id`) REFERENCES `buses` (`bus_id`) ON DELETE CASCADE,
  CONSTRAINT `student_boarding_ibfk_3` FOREIGN KEY (`driver_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 7. driver_trips
CREATE TABLE IF NOT EXISTS `driver_trips` (
  `trip_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `bus_id` int(11) DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'Not Started',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`trip_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 8. driver_locations
CREATE TABLE IF NOT EXISTS `driver_locations` (
  `location_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `latitude` decimal(10,7) NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 9. driver_emergencies
CREATE TABLE IF NOT EXISTS `driver_emergencies` (
  `emergency_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `emergency_type` varchar(50) DEFAULT 'Other',
  `message` text NOT NULL,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  `bus_id` int(11) DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'Pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`emergency_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 10. parent_registration_requests
CREATE TABLE IF NOT EXISTS `parent_registration_requests` (
  `request_id` int(11) NOT NULL AUTO_INCREMENT,
  `full_name` varchar(100) NOT NULL,
  `email` varchar(150) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `child_name` varchar(100) NOT NULL,
  `child_class` varchar(50) DEFAULT NULL,
  `status` enum('PENDING','APPROVED','REJECTED') DEFAULT 'PENDING',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`request_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 11. driver_phone_otp
CREATE TABLE IF NOT EXISTS `driver_phone_otp` (
  `otp_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `new_phone` varchar(20) NOT NULL,
  `otp_hash` varchar(255) NOT NULL,
  `expires_at` datetime NOT NULL,
  `attempts` int(11) DEFAULT 0,
  `verified` tinyint(1) DEFAULT 0,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`otp_id`),
  KEY `driver_id` (`driver_id`),
  CONSTRAINT `driver_phone_otp_ibfk_1` FOREIGN KEY (`driver_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 12. assignment_logs
CREATE TABLE IF NOT EXISTS `assignment_logs` (
  `log_id` int(11) NOT NULL AUTO_INCREMENT,
  `entity_type` varchar(50) NOT NULL,
  `entity_id` int(11) DEFAULT NULL,
  `action` varchar(50) NOT NULL,
  `details` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`log_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 13. child_bus_absence
CREATE TABLE IF NOT EXISTS `child_bus_absence` (
  `absence_id` int(11) NOT NULL AUTO_INCREMENT,
  `child_id` int(11) NOT NULL,
  `parent_id` int(11) NOT NULL,
  `route_id` int(11) DEFAULT NULL,
  `stop_id` int(11) DEFAULT NULL,
  `absence_date` date NOT NULL,
  `status` varchar(50) NOT NULL DEFAULT 'Not Riding Today',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`absence_id`),
  UNIQUE KEY `unique_child_daily_absence` (`child_id`,`absence_date`),
  KEY `fk_absence_child` (`child_id`),
  KEY `fk_absence_parent` (`parent_id`),
  CONSTRAINT `fk_absence_child` FOREIGN KEY (`child_id`) REFERENCES `parent_children` (`child_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_absence_parent` FOREIGN KEY (`parent_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 14. school_settings
CREATE TABLE IF NOT EXISTS `school_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `school_name` varchar(255) NOT NULL,
  `address` text NOT NULL,
  `latitude` double NOT NULL,
  `longitude` double NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Default School Settings
INSERT IGNORE INTO `school_settings` (`id`, `school_name`, `address`, `latitude`, `longitude`, `updated_at`) VALUES
(1, 'Saintgits College of Applied Sciences', 'Kottukulam Hills, Pathamuttom P.O., Kottayam, Kerala - 686532', 9.50921, 76.55183, CURRENT_TIMESTAMP);

SET FOREIGN_KEY_CHECKS = 1;
