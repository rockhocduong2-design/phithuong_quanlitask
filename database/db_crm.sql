-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Apr 10, 2026 at 12:38 PM
-- Server version: 9.1.0
-- PHP Version: 8.3.14

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `db_crm`
--
CREATE DATABASE IF NOT EXISTS `db_crm` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE `db_crm`;

DELIMITER $$
--
-- Procedures
--
DROP PROCEDURE IF EXISTS `sp_ConvertLeadToCustomer`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_ConvertLeadToCustomer` (IN `p_lead_id` BIGINT, IN `p_user_id` BIGINT, OUT `p_customer_id` BIGINT, OUT `p_contact_id` BIGINT, OUT `p_opportunity_id` BIGINT)   BEGIN
    DECLARE v_contact_name VARCHAR(150); DECLARE v_company_name VARCHAR(200); DECLARE v_phone VARCHAR(20); DECLARE v_email VARCHAR(150); DECLARE v_address VARCHAR(255); DECLARE v_province_id INT; DECLARE v_tax_code VARCHAR(50); DECLARE v_expected_revenue DECIMAL(15,2); DECLARE v_source_id BIGINT; DECLARE v_assigned_to BIGINT; DECLARE v_is_converted TINYINT;
    DECLARE exit handler for sqlexception BEGIN ROLLBACK; RESIGNAL; END;

    SELECT contact_name, company_name, phone, email, address, province_id, tax_code, expected_revenue, source_id, assigned_to, is_converted INTO v_contact_name, v_company_name, v_phone, v_email, v_address, v_province_id, v_tax_code, v_expected_revenue, v_source_id, v_assigned_to, v_is_converted FROM leads WHERE id = p_lead_id AND deleted_at IS NULL;
    IF v_is_converted = 1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lead đã được chuyển đổi!'; END IF;

    START TRANSACTION;
    -- 1. Create Customer
    INSERT INTO customers (type, name, short_name, tax_code, phone, email, description, source_id, assigned_to, created_by) VALUES (IF(v_company_name IS NOT NULL AND v_company_name != '', 'B2B', 'B2C'), IFNULL(v_company_name, v_contact_name), IFNULL(v_company_name, v_contact_name), v_tax_code, v_phone, v_email, CONCAT('Convert từ Lead ID: ', p_lead_id), v_source_id, v_assigned_to, p_user_id);
    SET p_customer_id = LAST_INSERT_ID();
    
    -- 2. Create Address
    IF v_address IS NOT NULL OR v_province_id IS NOT NULL THEN INSERT INTO customer_addresses (customer_id, address_type, full_address, province_id, is_primary) VALUES (p_customer_id, 'HQ', IFNULL(v_address, ''), v_province_id, 1); END IF;
    
    -- 3. Create Contact
    INSERT INTO contacts (customer_id, full_name, phone, email, address, is_primary, created_by) VALUES (p_customer_id, v_contact_name, v_phone, v_email, v_address, 1, p_user_id);
    SET p_contact_id = LAST_INSERT_ID();
    
    -- 4. Create Opportunity
    INSERT INTO opportunities (name, customer_id, total_amount, expected_close_date, assigned_user_id, created_by) VALUES (CONCAT('Cơ hội từ ', IFNULL(v_company_name, v_contact_name)), p_customer_id, v_expected_revenue, DATE_ADD(CURRENT_DATE, INTERVAL 30 DAY), v_assigned_to, p_user_id);
    SET p_opportunity_id = LAST_INSERT_ID();
    
    -- 5. Update Lead
    UPDATE leads SET status = 'CONVERTED', is_converted = 1, converted_customer_id = p_customer_id, converted_contact_id = p_contact_id, converted_opportunity_id = p_opportunity_id, converted_at = NOW(), updated_by = p_user_id WHERE id = p_lead_id;
    
    -- 6. Transfer Links (Activities, Tasks, Attachments)
    UPDATE activities SET related_to_type = 'CUSTOMER', related_to_id = p_customer_id, updated_by = p_user_id WHERE related_to_type = 'LEAD' AND related_to_id = p_lead_id;
    UPDATE tasks SET related_to_type = 'CUSTOMER', related_to_id = p_customer_id, updated_by = p_user_id WHERE related_to_type = 'LEAD' AND related_to_id = p_lead_id;
    UPDATE attachments SET attachable_type = 'CUSTOMER', attachable_id = p_customer_id WHERE attachable_type = 'LEAD' AND attachable_id = p_lead_id;
    
    -- 7. Audit
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, changes) VALUES (p_user_id, 'CONVERT', 'LEADS', p_lead_id, JSON_OBJECT('new_customer_id', p_customer_id, 'new_opportunity_id', p_opportunity_id, 'new_contact_id', p_contact_id));
    
    COMMIT;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `activities`
--

DROP TABLE IF EXISTS `activities`;
CREATE TABLE IF NOT EXISTS `activities` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `activity_type` tinyint NOT NULL,
  `subject` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `start_date` datetime DEFAULT NULL,
  `end_date` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `outcome` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `related_to_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `related_to_id` bigint NOT NULL,
  `performed_by` bigint NOT NULL,
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `status` tinyint DEFAULT NULL,
  `is_important` tinyint(1) DEFAULT '0',
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_activity_polymorphic` (`related_to_type`,`related_to_id`),
  KEY `fk_act_user` (`performed_by`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `activities`
--

INSERT INTO `activities` (`id`, `activity_type`, `subject`, `description`, `start_date`, `end_date`, `completed_at`, `outcome`, `related_to_type`, `related_to_id`, `performed_by`, `created_by`, `updated_by`, `created_at`, `updated_at`, `status`, `is_important`, `deleted_at`) VALUES
(1, 1, 'Đã gọi điện tư vấn qua Zalo', NULL, NULL, NULL, NULL, NULL, 'LEAD', 1, 2, NULL, NULL, '2026-04-08 08:16:28', '2026-04-08 08:16:28', NULL, 0, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `attachments`
--

DROP TABLE IF EXISTS `attachments`;
CREATE TABLE IF NOT EXISTS `attachments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file_size` int DEFAULT NULL,
  `attachable_type` enum('LEAD','CUSTOMER','OPPORTUNITY','CONTRACT','PRODUCT','ACTIVITY','TASK','FEEDBACK') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `attachable_id` bigint NOT NULL,
  `uploaded_by` bigint NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_attachable` (`attachable_type`,`attachable_id`),
  KEY `fk_attach_user` (`uploaded_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `audit_logs`
--

DROP TABLE IF EXISTS `audit_logs`;
CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `action` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'CREATE, UPDATE, DELETE, CONVERT',
  `entity_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'LEADS, QUOTES, CUSTOMERS...',
  `entity_id` bigint NOT NULL,
  `changes` json DEFAULT NULL COMMENT 'Lưu dạng JSON: {"field": {"old": 1, "new": 2}}',
  `ip_address` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_audit_entity` (`entity_type`,`entity_id`),
  KEY `idx_audit_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `campaigns`
--

DROP TABLE IF EXISTS `campaigns`;
CREATE TABLE IF NOT EXISTS `campaigns` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `categories`
--

DROP TABLE IF EXISTS `categories`;
CREATE TABLE IF NOT EXISTS `categories` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `contacts`
--

DROP TABLE IF EXISTS `contacts`;
CREATE TABLE IF NOT EXISTS `contacts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `customer_id` bigint NOT NULL,
  `full_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `position` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `dob` date DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_primary` tinyint(1) DEFAULT '0',
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_contact_cust` (`customer_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `contacts`
--

INSERT INTO `contacts` (`id`, `customer_id`, `full_name`, `position`, `phone`, `email`, `address`, `dob`, `notes`, `is_primary`, `created_by`, `updated_by`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 1, 'Trần Gia Nghi', NULL, '0909123456', NULL, NULL, NULL, NULL, 1, NULL, NULL, '2026-04-08 08:16:11', '2026-04-08 08:16:11', NULL),
(2, 1, 'Trần Thị Mai', 'Kế toán', '0911000002', 'mai@abc.com', NULL, NULL, NULL, 0, 1, NULL, '2026-04-09 15:31:24', '2026-04-09 15:31:24', NULL),
(3, 2, 'Nguyễn Văn A', 'Cá nhân', '0911000003', 'a@test.com', NULL, NULL, NULL, 1, 1, NULL, '2026-04-09 15:31:24', '2026-04-09 15:31:24', NULL),
(4, 3, 'Lê Văn Bình', 'Manager', '0911000004', 'binh@xyz.com', NULL, NULL, NULL, 1, 1, NULL, '2026-04-09 15:31:24', '2026-04-09 15:31:24', NULL),
(5, 3, 'Phạm Thị Lan', 'Sales', '0911000005', 'lan@xyz.com', NULL, NULL, NULL, 0, 1, NULL, '2026-04-09 15:31:24', '2026-04-09 15:31:24', NULL),
(6, 4, 'Trần Thị B', 'Cá nhân', '0911000006', 'b@test.com', NULL, NULL, NULL, 1, 1, NULL, '2026-04-09 15:31:24', '2026-04-09 15:31:24', NULL),
(7, 5, 'Hoàng Văn Nam', 'CEO', '0911000007', 'nam@def.com', NULL, NULL, NULL, 1, 1, NULL, '2026-04-09 15:31:24', '2026-04-09 15:31:24', NULL),
(8, 5, 'Đỗ Thị Hạnh', 'Marketing', '0911000008', 'hanh@def.com', NULL, NULL, NULL, 0, 1, NULL, '2026-04-09 15:31:24', '2026-04-09 15:31:24', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `contracts`
--

DROP TABLE IF EXISTS `contracts`;
CREATE TABLE IF NOT EXISTS `contracts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `contract_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `customer_id` bigint DEFAULT NULL,
  `quote_id` bigint DEFAULT NULL,
  `template_id` bigint DEFAULT NULL,
  `contract_value` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT '1.0000',
  `status` enum('DRAFT','SIGNED','ACTIVE','COMPLETED','CANCELLED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'DRAFT',
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `contract_number` (`contract_number`),
  KEY `fk_contract_cust` (`customer_id`),
  KEY `fk_contracts_template` (`template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `customers`
--

DROP TABLE IF EXISTS `customers`;
CREATE TABLE IF NOT EXISTS `customers` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `parent_id` bigint DEFAULT NULL,
  `customer_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` enum('B2B','B2C') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `short_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tax_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fax` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `established_date` date DEFAULT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `source_id` bigint DEFAULT NULL,
  `status_id` bigint DEFAULT NULL,
  `tier_id` bigint DEFAULT NULL,
  `assigned_to` bigint DEFAULT NULL,
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `customer_code` (`customer_code`),
  KEY `idx_cus_dashboard` (`assigned_to`,`status_id`),
  KEY `fk_cust_parent` (`parent_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `customers`
--

INSERT INTO `customers` (`id`, `parent_id`, `customer_code`, `type`, `name`, `short_name`, `tax_code`, `phone`, `email`, `fax`, `established_date`, `description`, `source_id`, `status_id`, `tier_id`, `assigned_to`, `created_by`, `updated_by`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, NULL, NULL, 'B2B', 'Công ty Công nghệ STU', NULL, NULL, '0281234567', 'contact@stu.vn', NULL, NULL, NULL, NULL, NULL, NULL, 2, 1, NULL, '2026-04-08 08:16:11', '2026-04-08 08:16:11', NULL),
(2, NULL, 'CUST002', 'B2C', 'Nguyễn Văn A', NULL, NULL, '0909000002', 'a@test.com', NULL, NULL, NULL, NULL, 1, NULL, 2, 1, NULL, '2026-04-09 15:29:34', '2026-04-09 15:29:34', NULL),
(3, 1, 'CUST003', 'B2B', 'Công ty XYZ', NULL, NULL, '0909000003', 'xyz@test.com', NULL, NULL, NULL, NULL, 2, NULL, 1, 1, NULL, '2026-04-09 15:29:34', '2026-04-09 15:29:34', NULL),
(4, NULL, 'CUST004', 'B2C', 'Trần Thị B', NULL, NULL, '0909000004', 'b@test.com', NULL, NULL, NULL, NULL, 1, NULL, 2, 1, NULL, '2026-04-09 15:29:34', '2026-04-09 15:29:34', NULL),
(5, NULL, 'CUST005', 'B2B', 'Công ty DEF', NULL, NULL, '0909000005', 'def@test.com', NULL, NULL, NULL, NULL, 3, NULL, 1, 1, NULL, '2026-04-09 15:29:34', '2026-04-09 15:29:34', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `customer_addresses`
--

DROP TABLE IF EXISTS `customer_addresses`;
CREATE TABLE IF NOT EXISTS `customer_addresses` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `customer_id` bigint NOT NULL,
  `address_type` enum('HQ','BILLING','SHIPPING','OTHER') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'HQ',
  `full_address` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `province_id` int DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_address_customer` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `document_templates`
--

DROP TABLE IF EXISTS `document_templates`;
CREATE TABLE IF NOT EXISTS `document_templates` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `type` enum('QUOTE','CONTRACT','INVOICE') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content_html` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `feedbacks`
--

DROP TABLE IF EXISTS `feedbacks`;
CREATE TABLE IF NOT EXISTS `feedbacks` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `customer_id` bigint NOT NULL,
  `subject` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `priority` enum('LOW','NORMAL','HIGH','URGENT') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'NORMAL',
  `status` enum('OPEN','IN_PROGRESS','RESOLVED','CLOSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'OPEN',
  `assigned_to` bigint DEFAULT NULL,
  `created_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_fb_cust` (`customer_id`),
  KEY `fk_fb_assign` (`assigned_to`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoices`
--

DROP TABLE IF EXISTS `invoices`;
CREATE TABLE IF NOT EXISTS `invoices` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `invoice_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `customer_id` bigint DEFAULT NULL,
  `order_id` bigint DEFAULT NULL,
  `template_id` bigint DEFAULT NULL,
  `total_amount` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT '1.0000',
  `issue_date` date DEFAULT NULL,
  `due_date` date DEFAULT NULL,
  `status` enum('DRAFT','SENT','PAID','OVERDUE','CANCELLED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'DRAFT',
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `invoice_number` (`invoice_number`),
  KEY `fk_inv_cust` (`customer_id`),
  KEY `fk_invoices_template` (`template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoice_line_items`
--

DROP TABLE IF EXISTS `invoice_line_items`;
CREATE TABLE IF NOT EXISTS `invoice_line_items` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `invoice_id` bigint NOT NULL,
  `product_id` bigint NOT NULL,
  `quantity` int NOT NULL,
  `unit_price` decimal(18,2) NOT NULL,
  `total_price` decimal(18,2) GENERATED ALWAYS AS ((`quantity` * `unit_price`)) STORED,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_ili_invoice` (`invoice_id`),
  KEY `fk_ili_product` (`product_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `kpi_configs`
--

DROP TABLE IF EXISTS `kpi_configs`;
CREATE TABLE IF NOT EXISTS `kpi_configs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'ACTIVE',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `kpi_targets`
--

DROP TABLE IF EXISTS `kpi_targets`;
CREATE TABLE IF NOT EXISTS `kpi_targets` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `kpi_config_id` bigint NOT NULL,
  `metric_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_value` decimal(15,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_kpit_conf` (`kpi_config_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `leads`
--

DROP TABLE IF EXISTS `leads`;
CREATE TABLE IF NOT EXISTS `leads` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `contact_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `company_name` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `website` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tax_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `citizen_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `province_id` int DEFAULT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `expected_revenue` decimal(15,2) DEFAULT NULL,
  `status` enum('NEW','CONTACTING','CONVERTED','LOST') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'NEW',
  `source_id` bigint DEFAULT NULL,
  `campaign_id` bigint DEFAULT NULL,
  `organization_id` bigint DEFAULT NULL,
  `assigned_to` bigint DEFAULT NULL,
  `is_converted` tinyint(1) DEFAULT '0',
  `converted_customer_id` bigint DEFAULT NULL,
  `converted_contact_id` bigint DEFAULT NULL,
  `converted_opportunity_id` bigint DEFAULT NULL,
  `converted_at` datetime DEFAULT NULL,
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_lead_phone` (`phone`),
  KEY `idx_lead_dashboard` (`assigned_to`,`status`),
  KEY `fk_lead_org` (`organization_id`),
  KEY `fk_lead_conv_cust` (`converted_customer_id`),
  KEY `fk_leads_campaign` (`campaign_id`),
  KEY `fk_leads_province` (`province_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `leads`
--

INSERT INTO `leads` (`id`, `contact_name`, `company_name`, `phone`, `email`, `address`, `website`, `tax_code`, `citizen_id`, `province_id`, `description`, `expected_revenue`, `status`, `source_id`, `campaign_id`, `organization_id`, `assigned_to`, `is_converted`, `converted_customer_id`, `converted_contact_id`, `converted_opportunity_id`, `converted_at`, `created_by`, `updated_by`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'Anh Khách Tiềm Năng', NULL, '0988777666', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'NEW', NULL, NULL, 2, 2, 0, NULL, NULL, NULL, NULL, NULL, NULL, '2026-04-08 08:16:11', '2026-04-08 08:16:11', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `lead_product_interests`
--

DROP TABLE IF EXISTS `lead_product_interests`;
CREATE TABLE IF NOT EXISTS `lead_product_interests` (
  `lead_id` bigint NOT NULL,
  `product_id` bigint NOT NULL,
  PRIMARY KEY (`lead_id`,`product_id`),
  KEY `fk_lpi_prod` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `loss_reasons`
--

DROP TABLE IF EXISTS `loss_reasons`;
CREATE TABLE IF NOT EXISTS `loss_reasons` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `menus`
--

DROP TABLE IF EXISTS `menus`;
CREATE TABLE IF NOT EXISTS `menus` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `parent_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_menu_parent` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notes`
--

DROP TABLE IF EXISTS `notes`;
CREATE TABLE IF NOT EXISTS `notes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `notable_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `notable_id` bigint NOT NULL,
  `created_by` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_note_polymorphic` (`notable_type`,`notable_id`,`created_date` DESC),
  KEY `idx_note_created` (`created_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `opportunities`
--

DROP TABLE IF EXISTS `opportunities`;
CREATE TABLE IF NOT EXISTS `opportunities` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `customer_id` bigint DEFAULT NULL,
  `pipeline_id` bigint DEFAULT NULL,
  `stage_id` bigint DEFAULT NULL,
  `total_amount` decimal(15,2) DEFAULT NULL,
  `deposit_amount` decimal(15,2) DEFAULT NULL,
  `remaining_amount` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT '1.0000',
  `expected_close_date` date DEFAULT NULL,
  `loss_reason_id` bigint DEFAULT NULL,
  `health_status` enum('ON_TRACK','AT_RISK','OFF_TRACK') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'ON_TRACK',
  `assigned_user_id` bigint DEFAULT NULL,
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_opp_dashboard` (`assigned_user_id`,`stage_id`),
  KEY `fk_opp_cust` (`customer_id`),
  KEY `fk_opp_stage` (`stage_id`),
  KEY `fk_opp_loss` (`loss_reason_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `orders`
--

DROP TABLE IF EXISTS `orders`;
CREATE TABLE IF NOT EXISTS `orders` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `order_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `customer_id` bigint DEFAULT NULL,
  `opportunity_id` bigint DEFAULT NULL,
  `total_amount` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT '1.0000',
  `status` enum('DRAFT','CONFIRMED','PROCESSING','COMPLETED','CANCELLED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'DRAFT',
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `order_number` (`order_number`),
  KEY `fk_order_cust` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `order_line_items`
--

DROP TABLE IF EXISTS `order_line_items`;
CREATE TABLE IF NOT EXISTS `order_line_items` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `order_id` bigint NOT NULL,
  `product_id` bigint NOT NULL,
  `quantity` int NOT NULL,
  `unit_price` decimal(18,2) NOT NULL,
  `total_price` decimal(18,2) GENERATED ALWAYS AS ((`quantity` * `unit_price`)) STORED,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_oli_order` (`order_id`),
  KEY `fk_oli_product` (`product_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `organizations`
--

DROP TABLE IF EXISTS `organizations`;
CREATE TABLE IF NOT EXISTS `organizations` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `parent_id` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_org_parent` (`parent_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `organizations`
--

INSERT INTO `organizations` (`id`, `name`, `parent_id`, `created_at`, `updated_at`) VALUES
(1, 'Tổng công ty CRM', NULL, '2026-04-08 08:15:36', '2026-04-08 08:15:36'),
(2, 'Phòng Kinh doanh Miền Nam', 1, '2026-04-08 08:15:36', '2026-04-08 08:15:36');

-- --------------------------------------------------------

--
-- Table structure for table `pipelines`
--

DROP TABLE IF EXISTS `pipelines`;
CREATE TABLE IF NOT EXISTS `pipelines` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `pipeline_stages`
--

DROP TABLE IF EXISTS `pipeline_stages`;
CREATE TABLE IF NOT EXISTS `pipeline_stages` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `pipeline_id` bigint NOT NULL,
  `stage_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `probability` int DEFAULT NULL,
  `max_days_allowed` int DEFAULT NULL COMMENT 'SLA cảnh báo ngâm Deal',
  `sort_order` int DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_stage_pipe` (`pipeline_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

DROP TABLE IF EXISTS `products`;
CREATE TABLE IF NOT EXISTS `products` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `sku_code` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('PRODUCT','SERVICE') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PRODUCT',
  `category_id` bigint DEFAULT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_active` tinyint(1) DEFAULT '1',
  `created_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_product_sku` (`sku_code`),
  KEY `fk_prod_cat` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `product_prices`
--

DROP TABLE IF EXISTS `product_prices`;
CREATE TABLE IF NOT EXISTS `product_prices` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `product_id` bigint NOT NULL,
  `base_price` decimal(15,2) DEFAULT NULL,
  `tax_rate` decimal(5,2) DEFAULT NULL,
  `final_price` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'VND',
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_price_prod` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `provinces`
--

DROP TABLE IF EXISTS `provinces`;
CREATE TABLE IF NOT EXISTS `provinces` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `provinces`
--

INSERT INTO `provinces` (`id`, `name`, `code`) VALUES
(1, 'Hồ Chí Minh', 'SG'),
(2, 'Hà Nội', 'HN');

-- --------------------------------------------------------

--
-- Table structure for table `quotes`
--

DROP TABLE IF EXISTS `quotes`;
CREATE TABLE IF NOT EXISTS `quotes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `quote_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `customer_id` bigint DEFAULT NULL,
  `opportunity_id` bigint DEFAULT NULL,
  `status_id` bigint DEFAULT NULL,
  `total_amount` decimal(15,2) DEFAULT '0.00',
  `currency_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT '1.0000',
  `valid_until` date DEFAULT NULL,
  `template_id` bigint DEFAULT NULL,
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `quote_number` (`quote_number`),
  KEY `fk_quote_cust` (`customer_id`),
  KEY `fk_quotes_template` (`template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `quote_line_items`
--

DROP TABLE IF EXISTS `quote_line_items`;
CREATE TABLE IF NOT EXISTS `quote_line_items` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `quote_id` bigint NOT NULL,
  `product_id` bigint DEFAULT NULL,
  `quantity` int NOT NULL,
  `unit_price` decimal(15,2) NOT NULL,
  `discount_value` decimal(15,2) DEFAULT '0.00',
  `line_total` decimal(15,2) GENERATED ALWAYS AS (((`quantity` * `unit_price`) - `discount_value`)) STORED,
  PRIMARY KEY (`id`),
  KEY `fk_qli_quote` (`quote_id`),
  KEY `fk_qli_prod` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Triggers `quote_line_items`
--
DROP TRIGGER IF EXISTS `trg_qli_after_delete`;
DELIMITER $$
CREATE TRIGGER `trg_qli_after_delete` AFTER DELETE ON `quote_line_items` FOR EACH ROW BEGIN UPDATE quotes q SET q.total_amount = (SELECT IFNULL(SUM(line_total), 0) FROM quote_line_items WHERE quote_id = OLD.quote_id) WHERE q.id = OLD.quote_id; END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `trg_qli_after_insert`;
DELIMITER $$
CREATE TRIGGER `trg_qli_after_insert` AFTER INSERT ON `quote_line_items` FOR EACH ROW BEGIN UPDATE quotes q SET q.total_amount = (SELECT IFNULL(SUM(line_total), 0) FROM quote_line_items WHERE quote_id = NEW.quote_id) WHERE q.id = NEW.quote_id; END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `trg_qli_after_update`;
DELIMITER $$
CREATE TRIGGER `trg_qli_after_update` AFTER UPDATE ON `quote_line_items` FOR EACH ROW BEGIN UPDATE quotes q SET q.total_amount = (SELECT IFNULL(SUM(line_total), 0) FROM quote_line_items WHERE quote_id = OLD.quote_id) WHERE q.id = OLD.quote_id; IF NEW.quote_id <> OLD.quote_id THEN UPDATE quotes q SET q.total_amount = (SELECT IFNULL(SUM(line_total), 0) FROM quote_line_items WHERE quote_id = NEW.quote_id) WHERE q.id = NEW.quote_id; END IF; END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
CREATE TABLE IF NOT EXISTS `roles` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `roles`
--

INSERT INTO `roles` (`id`, `name`, `description`) VALUES
(1, 'Admin', 'Quản trị hệ thống'),
(2, 'Manager', 'Quản lý bộ phận'),
(3, 'Sales', 'Nhân viên kinh doanh');

-- --------------------------------------------------------

--
-- Table structure for table `role_menu_permissions`
--

DROP TABLE IF EXISTS `role_menu_permissions`;
CREATE TABLE IF NOT EXISTS `role_menu_permissions` (
  `role_id` bigint NOT NULL,
  `menu_id` bigint NOT NULL,
  `can_view` tinyint(1) DEFAULT '0',
  `can_create` tinyint(1) DEFAULT '0',
  `can_update` tinyint(1) DEFAULT '0',
  `can_delete` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`role_id`,`menu_id`),
  KEY `menu_id` (`menu_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `stage_checklists`
--

DROP TABLE IF EXISTS `stage_checklists`;
CREATE TABLE IF NOT EXISTS `stage_checklists` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `stage_id` bigint NOT NULL,
  `task_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_mandatory` tinyint(1) DEFAULT '1',
  `sort_order` int DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_check_stage` (`stage_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sys_configs`
--

DROP TABLE IF EXISTS `sys_configs`;
CREATE TABLE IF NOT EXISTS `sys_configs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `config_key` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'timezone, language, default_currency, smtp_server...',
  `config_value` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sys_customer_statuses`
--

DROP TABLE IF EXISTS `sys_customer_statuses`;
CREATE TABLE IF NOT EXISTS `sys_customer_statuses` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sys_customer_tiers`
--

DROP TABLE IF EXISTS `sys_customer_tiers`;
CREATE TABLE IF NOT EXISTS `sys_customer_tiers` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `min_spending` decimal(15,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sys_lead_sources`
--

DROP TABLE IF EXISTS `sys_lead_sources`;
CREATE TABLE IF NOT EXISTS `sys_lead_sources` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sys_lead_sources`
--

INSERT INTO `sys_lead_sources` (`id`, `name`) VALUES
(1, 'Facebook'),
(2, 'Website'),
(3, 'Giới thiệu');

-- --------------------------------------------------------

--
-- Table structure for table `target_assignments`
--

DROP TABLE IF EXISTS `target_assignments`;
CREATE TABLE IF NOT EXISTS `target_assignments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `kpi_config_id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL COMMENT 'Áp dụng cho Cá nhân',
  `organization_id` bigint DEFAULT NULL COMMENT 'Áp dụng cho Nhóm/Phòng ban',
  `commission_percent` decimal(5,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_ta_conf` (`kpi_config_id`),
  KEY `fk_ta_user` (`user_id`),
  KEY `fk_ta_org` (`organization_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `tasks`
--

DROP TABLE IF EXISTS `tasks`;
CREATE TABLE IF NOT EXISTS `tasks` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `subject` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `start_date` datetime DEFAULT NULL,
  `due_date` datetime NOT NULL,
  `completed_at` datetime DEFAULT NULL,
  `status` enum('NOT_STARTED','IN_PROGRESS','WAITING','COMPLETED','DEFERRED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'NOT_STARTED',
  `priority` enum('LOW','NORMAL','HIGH','URGENT') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'NORMAL',
  `progress_percent` int DEFAULT '0',
  `related_to_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `related_to_id` bigint DEFAULT NULL,
  `assigned_to` bigint NOT NULL,
  `assigned_by` bigint NOT NULL,
  `created_by` bigint DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `contact_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_task_assignee` (`assigned_to`),
  KEY `idx_task_polymorphic` (`related_to_type`,`related_to_id`),
  KEY `fk_task_assigner` (`assigned_by`),
  KEY `fk_tasks_contact` (`contact_id`)
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `tasks`
--

INSERT INTO `tasks` (`id`, `subject`, `description`, `start_date`, `due_date`, `completed_at`, `status`, `priority`, `progress_percent`, `related_to_type`, `related_to_id`, `assigned_to`, `assigned_by`, `created_by`, `updated_by`, `created_at`, `updated_at`, `deleted_at`, `contact_id`) VALUES
(12, 'A', 'aaaaa', '2026-04-11 03:15:00', '2026-04-17 15:15:00', NULL, 'NOT_STARTED', 'NORMAL', 0, 'CUSTOMER', 1, 2, 1, NULL, NULL, '2026-04-09 10:15:31', '2026-04-09 10:15:31', NULL, 2),
(13, 'B', 'bbbbb', NULL, '2026-04-17 17:15:00', NULL, 'NOT_STARTED', 'NORMAL', 0, 'CUSTOMER', 2, 2, 1, NULL, NULL, '2026-04-09 10:16:02', '2026-04-09 10:16:02', NULL, 3),
(15, 'C', 'xin chào hihi', NULL, '2026-04-30 06:44:00', NULL, 'NOT_STARTED', 'NORMAL', 0, 'CUSTOMER', 5, 1, 1, NULL, NULL, '2026-04-09 10:44:02', '2026-04-09 10:44:21', NULL, 7),
(16, 'Lên kế hoạch bàn giao công việc ', '', '2026-04-24 04:07:00', '2026-04-25 04:07:00', NULL, 'NOT_STARTED', 'NORMAL', 0, 'CUSTOMER', 3, 2, 1, NULL, NULL, '2026-04-09 21:07:54', '2026-04-09 21:07:54', NULL, 5),
(17, 'HAHHA', 'Helllo HIHI', '2026-04-10 04:48:00', '2026-04-11 04:48:00', NULL, 'NOT_STARTED', 'URGENT', 0, 'CUSTOMER', 4, 2, 1, NULL, NULL, '2026-04-09 21:48:46', '2026-04-09 21:48:46', NULL, 6),
(25, 'Xin chào', 'helllo hihi', NULL, '2026-04-11 08:41:00', NULL, 'NOT_STARTED', 'NORMAL', 0, NULL, NULL, 1, 1, NULL, NULL, '2026-04-10 01:41:14', '2026-04-10 01:41:14', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE IF NOT EXISTS `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `full_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role_id` bigint NOT NULL,
  `organization_id` bigint NOT NULL,
  `status` enum('ACTIVE','INACTIVE','LOCKED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'ACTIVE',
  `ui_preferences` json DEFAULT NULL COMMENT 'Cấu hình UI Dashboard cá nhân',
  `last_login` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_user_role` (`role_id`),
  KEY `idx_user_org` (`organization_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `username`, `password`, `email`, `full_name`, `role_id`, `organization_id`, `status`, `ui_preferences`, `last_login`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'duy_admin', '123456', 'duy@stu.edu.vn', 'Duy Admin', 1, 1, 'ACTIVE', NULL, NULL, '2026-04-08 08:15:57', '2026-04-08 08:15:57', NULL),
(2, 'nhanvien_01', '123456', 'sale1@stu.edu.vn', 'Nguyễn Văn Sale', 3, 2, 'ACTIVE', NULL, NULL, '2026-04-08 08:15:57', '2026-04-08 08:15:57', NULL);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `activities`
--
ALTER TABLE `activities`
  ADD CONSTRAINT `fk_act_user` FOREIGN KEY (`performed_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `attachments`
--
ALTER TABLE `attachments`
  ADD CONSTRAINT `fk_attach_user` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `contacts`
--
ALTER TABLE `contacts`
  ADD CONSTRAINT `fk_contact_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `contracts`
--
ALTER TABLE `contracts`
  ADD CONSTRAINT `fk_contract_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_contracts_template` FOREIGN KEY (`template_id`) REFERENCES `document_templates` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `customers`
--
ALTER TABLE `customers`
  ADD CONSTRAINT `fk_cust_assign` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_cust_parent` FOREIGN KEY (`parent_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `customer_addresses`
--
ALTER TABLE `customer_addresses`
  ADD CONSTRAINT `fk_addr_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `feedbacks`
--
ALTER TABLE `feedbacks`
  ADD CONSTRAINT `fk_fb_assign` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_fb_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `invoices`
--
ALTER TABLE `invoices`
  ADD CONSTRAINT `fk_inv_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_invoices_template` FOREIGN KEY (`template_id`) REFERENCES `document_templates` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `kpi_targets`
--
ALTER TABLE `kpi_targets`
  ADD CONSTRAINT `fk_kpit_conf` FOREIGN KEY (`kpi_config_id`) REFERENCES `kpi_configs` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `leads`
--
ALTER TABLE `leads`
  ADD CONSTRAINT `fk_lead_assign` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_lead_conv_cust` FOREIGN KEY (`converted_customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_lead_org` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_leads_campaign` FOREIGN KEY (`campaign_id`) REFERENCES `campaigns` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_leads_province` FOREIGN KEY (`province_id`) REFERENCES `provinces` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `lead_product_interests`
--
ALTER TABLE `lead_product_interests`
  ADD CONSTRAINT `fk_lpi_lead` FOREIGN KEY (`lead_id`) REFERENCES `leads` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_lpi_prod` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `menus`
--
ALTER TABLE `menus`
  ADD CONSTRAINT `fk_menu_parent` FOREIGN KEY (`parent_id`) REFERENCES `menus` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `notes`
--
ALTER TABLE `notes`
  ADD CONSTRAINT `fk_note_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `opportunities`
--
ALTER TABLE `opportunities`
  ADD CONSTRAINT `fk_opp_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`),
  ADD CONSTRAINT `fk_opp_loss` FOREIGN KEY (`loss_reason_id`) REFERENCES `loss_reasons` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_opp_stage` FOREIGN KEY (`stage_id`) REFERENCES `pipeline_stages` (`id`);

--
-- Constraints for table `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `fk_order_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`);

--
-- Constraints for table `organizations`
--
ALTER TABLE `organizations`
  ADD CONSTRAINT `fk_org_parent` FOREIGN KEY (`parent_id`) REFERENCES `organizations` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `pipeline_stages`
--
ALTER TABLE `pipeline_stages`
  ADD CONSTRAINT `fk_stage_pipe` FOREIGN KEY (`pipeline_id`) REFERENCES `pipelines` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `products`
--
ALTER TABLE `products`
  ADD CONSTRAINT `fk_prod_cat` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `product_prices`
--
ALTER TABLE `product_prices`
  ADD CONSTRAINT `fk_price_prod` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `quotes`
--
ALTER TABLE `quotes`
  ADD CONSTRAINT `fk_quote_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_quotes_template` FOREIGN KEY (`template_id`) REFERENCES `document_templates` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `quote_line_items`
--
ALTER TABLE `quote_line_items`
  ADD CONSTRAINT `fk_qli_prod` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_qli_quote` FOREIGN KEY (`quote_id`) REFERENCES `quotes` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `role_menu_permissions`
--
ALTER TABLE `role_menu_permissions`
  ADD CONSTRAINT `role_menu_permissions_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `role_menu_permissions_ibfk_2` FOREIGN KEY (`menu_id`) REFERENCES `menus` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `stage_checklists`
--
ALTER TABLE `stage_checklists`
  ADD CONSTRAINT `fk_check_stage` FOREIGN KEY (`stage_id`) REFERENCES `pipeline_stages` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `target_assignments`
--
ALTER TABLE `target_assignments`
  ADD CONSTRAINT `fk_ta_conf` FOREIGN KEY (`kpi_config_id`) REFERENCES `kpi_configs` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_ta_org` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_ta_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `tasks`
--
ALTER TABLE `tasks`
  ADD CONSTRAINT `fk_task_assignee` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `fk_task_assigner` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `fk_tasks_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `fk_user_org` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE RESTRICT,
  ADD CONSTRAINT `fk_user_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE RESTRICT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
