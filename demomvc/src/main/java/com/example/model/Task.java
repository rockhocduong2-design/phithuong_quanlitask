package com.example.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;
import java.time.LocalDateTime;

import org.springframework.format.annotation.DateTimeFormat;

@Data
@Entity
@Table(name = "tasks")
public class Task {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank(message = "Chủ đề không được để trống")
    @Size(max = 255, message = "Chủ đề không được vượt quá 255 ký tự")
    private String subject;

    @Column(columnDefinition = "TEXT")
    private String description;

    @DateTimeFormat(pattern = "yyyy-MM-dd'T'HH:mm")
    @Column(name = "start_date")
    private LocalDateTime startDate;

    @DateTimeFormat(pattern = "yyyy-MM-dd'T'HH:mm")
    @Column(name = "due_date", nullable = false)
    private LocalDateTime dueDate;

    @Enumerated(EnumType.STRING)
    private Status status = Status.NOT_STARTED;

    @Enumerated(EnumType.STRING)
    private Priority priority = Priority.NORMAL;

    @Column(name = "progress_percent")
    private Integer progressPercent = 0;

    @ManyToOne
    @JoinColumn(name = "assigned_to", nullable = false)
    private User assignedTo;

    @ManyToOne
    @JoinColumn(name = "assigned_by", nullable = false)
    private User assignedBy;

    @ManyToOne
    @JoinColumn(name = "contact_id")
    private Contact contact;

    public enum Status {
        NOT_STARTED, IN_PROGRESS, WAITING, COMPLETED, DEFERRED
    }

    public enum Priority {
        LOW, NORMAL, HIGH, URGENT
    }

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

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    @Column(name = "related_to_type", length = 50)
    @Enumerated(EnumType.STRING)
    private RelatedType relatedToType;

    public enum RelatedType {
        CUSTOMER("Khách hàng (Công ty)"),
        DEAL("Cơ hội bán hàng"),
        CAMPAIGN("Chiến dịch"),
        TICKET("Yêu cầu hỗ trợ"),
        PROJECT("Dự án"),
        INVOICE("Hóa đơn"),
        CONTACT("Khách hàng / Liên hệ");

        private final String displayName;

        RelatedType(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() {
            return displayName;
        }
    }

    @Column(name = "related_to_id")
    private Long relatedToId;

    @Transient // Báo cho Spring biết cột này KHÔNG CÓ trong database
    private String relatedObjectName; // Chứa tên hiển thị (VD: "Dự án Aqua City")
}