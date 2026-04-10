package com.example.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "customers")
public class Customer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Tự tham chiếu: Một công ty có thể là công ty con của một công ty khác (parent_id)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_id")
    private Customer parent;

    @Column(name = "customer_code", unique = true, length = 50)
    private String customerCode;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private CustomerType type;

    public enum CustomerType {
        B2B, B2C
    }

    @Column(nullable = false)
    private String name;

    @Column(name = "short_name", length = 100)
    private String shortName;

    @Column(name = "tax_code", length = 50)
    private String taxCode;

    @Column(length = 20)
    private String phone;

    @Column(length = 100)
    private String email;

    @Column(length = 50)
    private String fax;

    @Column(name = "established_date")
    private LocalDate establishedDate;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "source_id")
    private Long sourceId;

    @Column(name = "status_id")
    private Long statusId;

    @Column(name = "tier_id")
    private Long tierId;

    // Gán cho nhân viên nào phụ trách
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_to")
    private User assignedTo;

    // Các trường Tracking tự động
    @Column(name = "created_by")
    private Long createdBy;

    @Column(name = "updated_by")
    private Long updatedBy;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;
    
    // Tự động set thời gian khi tạo mới hoặc cập nhật
    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}