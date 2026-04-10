package com.example.repository;

import com.example.model.Task;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.time.LocalDateTime;

@Repository
public interface TaskRepository extends JpaRepository<Task, Long> {

    // Câu lệnh này sẽ tự động bỏ qua điều kiện nếu tham số truyền vào là null hoặc
    // rỗng
    @Query("SELECT t FROM Task t WHERE " +
            "(:keyword IS NULL OR :keyword = '' OR LOWER(t.subject) LIKE LOWER(CONCAT('%', :keyword, '%'))) " +
            "AND (:status IS NULL OR t.status = :status)" +
            "AND (:assigneeId IS NULL OR t.assignedTo.id = :assigneeId)" +
            "AND (:priority IS NULL OR t.priority = :priority) " +
            "AND (cast(:fromDate as timestamp) IS NULL OR t.dueDate >= :fromDate) " +
            "AND (cast(:toDate as timestamp) IS NULL OR t.dueDate <= :toDate)")
    List<Task> searchTasks(@Param("keyword") String keyword,
            @Param("status") Task.Status status,
            @Param("assigneeId") Long assigneeId,
            @Param("priority") Task.Priority priority,
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate);
}