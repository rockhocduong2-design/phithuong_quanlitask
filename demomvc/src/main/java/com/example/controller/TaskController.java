package com.example.controller;

import com.example.model.Customer;
import com.example.model.Task;
import com.example.model.User;
import com.example.repository.TaskRepository;
import com.example.repository.UserRepository;
import com.example.repository.ContactRepository;
import com.example.repository.CustomerRepository;

import lombok.RequiredArgsConstructor;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import jakarta.validation.Valid;
import org.springframework.validation.BindingResult;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

@Controller
@RequestMapping("/tasks")
@RequiredArgsConstructor
public class TaskController {

    // (inject)
    private final TaskRepository taskRepository;
    private final UserRepository userRepository;
    private final ContactRepository contactRepository;
    private final CustomerRepository customerRepository;

    @GetMapping
    public String listTasks(
            @RequestParam(value = "keyword", required = false) String keyword,
            @RequestParam(value = "status", required = false) Task.Status status,
            @RequestParam(value = "assigneeId", required = false) Long assigneeId,
            @RequestParam(value = "priority", required = false) Task.Priority priority,
            @RequestParam(value = "fromDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(value = "toDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate,
            Model model) {
        // Truyền danh sách nhân viên ra để làm thẻ <select>
        model.addAttribute("users", userRepository.findAll());
        model.addAttribute("currentAssignee", assigneeId); // Giữ trạng thái khi load lại

        // 1. Ép kiểu Ngày (LocalDate) sang Ngày Giờ (LocalDateTime) để so sánh với
        // Database
        LocalDateTime startDateTime = (fromDate != null) ? fromDate.atStartOfDay() : null; // 00:00:00
        LocalDateTime endDateTime = (toDate != null) ? toDate.atTime(LocalTime.MAX) : null; // 23:59:59

        List<Task> tasks;
        if ((keyword != null && !keyword.isEmpty()) || status != null || assigneeId != null || priority != null
                || fromDate != null || toDate != null) {
            tasks = taskRepository.searchTasks(keyword, status, assigneeId, priority, startDateTime, endDateTime);
        } else {
            tasks = taskRepository.findAll();
        }

        // Dịch ID thành Tên cho cột Đa hình
        for (Task task : tasks) {
            if (task.getRelatedToType() != null && task.getRelatedToId() != null) {
                String name = "";
                Long id = task.getRelatedToId();

                // Dựa vào Type để gọi đúng Repository
                switch (task.getRelatedToType()) {
                    case CUSTOMER:
                        name = customerRepository.findById(id)
                                .map(Customer::getName).orElse("Khách hàng ẩn");
                        break;
                    case DEAL:
                        // name =
                        // opportunityRepository.findById(id).map(Opportunity::getName).orElse("");
                        break;
                    // Thêm các case CAMPAIGN, PROJECT... tương tự
                }

                // Nếu có tên thì ghép chung với tên Type cho đẹp (VD: Công ty: Mobifone)
                if (!name.isEmpty()) {
                    task.setRelatedObjectName(task.getRelatedToType().getDisplayName() + ": " + name);
                }
            }
        }
        // 3. Đẩy dữ liệu ra giao diện (Để giữ trạng thái người dùng đã chọn)
        model.addAttribute("taskList", tasks);
        model.addAttribute("keyword", keyword);
        model.addAttribute("currentStatus", status);
        model.addAttribute("currentAssignee", assigneeId);
        model.addAttribute("currentPriority", priority);
        model.addAttribute("fromDate", fromDate);
        model.addAttribute("toDate", toDate);

        // Đẩy danh sách Enum và User ra cho các thẻ Select
        model.addAttribute("statuses", Task.Status.values());
        model.addAttribute("priorities", Task.Priority.values());
        model.addAttribute("users", userRepository.findAll());

        boolean hasAdvancedFilter = (priority != null || fromDate != null || toDate != null);
        model.addAttribute("hasAdvancedFilter", hasAdvancedFilter);

        // 3. Trả về view:
        return "task-list";
    }

    // 2. Hiển thị Form thêm mới
    @GetMapping("/create")
    public String showCreateForm(Model model) {

        model.addAttribute("task", new Task());
        model.addAttribute("users", userRepository.findAll());
        model.addAttribute("contacts", contactRepository.findAll());
        model.addAttribute("relatedTypes", Task.RelatedType.values());

        return "task-form";
    }

    // 3. Xử lý lưu Task vào Database
    @PostMapping("/create")
    public String saveTask(@ModelAttribute("task") Task task, BindingResult bindingResult, Model model,
            RedirectAttributes redirectAttributes) {
        if (bindingResult.hasErrors()) {

            model.addAttribute("users", userRepository.findAll());
            model.addAttribute("contacts", contactRepository.findAll());
            model.addAttribute("relatedTypes", Task.RelatedType.values());

            return "task-form";
        }

        if (task.getContact() != null && task.getContact().getId() == null) {
            task.setContact(null);
        }

        // Tương tự, nếu bạn có trường "Người đảm nhiệm" cũng bị lỗi tương tự thì thêm:
        if (task.getAssignedTo() != null && task.getAssignedTo().getId() == null) {
            task.setAssignedTo(null);
        }

        // 1. Tạo object User đại diện cho người giao việc (ID = 1)
        User assigner = new User();
        assigner.setId(1L);
        task.setAssignedBy(assigner);

        // 3. Set các giá trị mặc định khác
        task.setStatus(Task.Status.NOT_STARTED);
        task.setProgressPercent(0);

        taskRepository.save(task);
        redirectAttributes.addFlashAttribute("message", "✅ Đã tạo công việc thành công!");

        return "redirect:/tasks";
    }

    @GetMapping("/view/{id}")
    public String viewTaskDetail(@PathVariable("id") Long id, Model model) {
        // 1. Tìm Task theo ID. Nếu không thấy thì báo lỗi hoặc quay về trang list
        Task task = taskRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy Task mang mã số: " + id));

        // 2. Tái sử dụng logic "Dịch ID thành Tên" cho cột Liên quan đến (Đa hình)
        if (task.getRelatedToType() != null && task.getRelatedToId() != null) {
            String name = "-";
            Long relatedId = task.getRelatedToId();

            switch (task.getRelatedToType()) {
                case CUSTOMER:
                    name = customerRepository.findById(relatedId).map(Customer::getName).orElse("-");
                    break;
                // Thêm case DEAL, CAMPAIGN ở đây nếu bạn đã có Model
            }
            task.setRelatedObjectName(task.getRelatedToType().getDisplayName() + ": " + name);
        }

        model.addAttribute("task", task);
        return "task-detail";
    }

    @PostMapping("/delete/{id}")
    public String deleteTask(@PathVariable("id") Long id) {
        taskRepository.deleteById(id);
        return "redirect:/tasks"; // Xóa xong thì tự động quay về trang danh sách
    }

    // Xóa hàng loạt từ Checkbox
    @PostMapping("/bulk-delete")
    public String bulkDeleteTasks(@RequestParam(value = "ids", required = false) List<Long> ids,
            RedirectAttributes redirectAttributes) {
        if (ids != null && !ids.isEmpty()) {
            taskRepository.deleteAllById(ids);
            redirectAttributes.addFlashAttribute("message", "🗑️ Đã xóa thành công " + ids.size() + " công việc!");
        }
        return "redirect:/tasks";
    }

    @GetMapping("/edit/{id}")
    public String showEditForm(@PathVariable("id") Long id, Model model) {
        Task task = taskRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy Task: " + id));

        model.addAttribute("task", task);

        model.addAttribute("users", userRepository.findAll());
        model.addAttribute("contacts", contactRepository.findAll());
        model.addAttribute("relatedTypes", Task.RelatedType.values());

        if (task.getRelatedToType() != null && task.getRelatedToId() != null) {
            String relatedName = "";
            if (task.getRelatedToType() == Task.RelatedType.CUSTOMER) {
                relatedName = customerRepository.findById(task.getRelatedToId())
                        .map(Customer::getName).orElse("");
            }

            model.addAttribute("relatedName", relatedName);
        }

        return "task-form"; // Tái sử dụng lại file HTML form tạo mới!
    }

    // 2. Lưu dữ liệu sau khi sửa
    @PostMapping("/edit/{id}")
    public String updateTask(@PathVariable("id") Long id, @ModelAttribute("task") Task taskData) {

        // Lấy Task cũ từ DB lên để không bị mất các trường như createdAt
        Task existingTask = taskRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy Task: " + id));

        // Cập nhật các trường người dùng vừa sửa trên form
        existingTask.setSubject(taskData.getSubject());
        existingTask.setDescription(taskData.getDescription());
        existingTask.setStartDate(taskData.getStartDate());
        existingTask.setDueDate(taskData.getDueDate());
        existingTask.setStatus(taskData.getStatus());
        existingTask.setPriority(taskData.getPriority());
        existingTask.setProgressPercent(taskData.getProgressPercent());
        existingTask.setAssignedTo(taskData.getAssignedTo());
        existingTask.setContact(taskData.getContact());

        // Cập nhật trường đa hình
        existingTask.setRelatedToType(taskData.getRelatedToType());
        existingTask.setRelatedToId(taskData.getRelatedToId());

        // Lưu lại xuống CSDL (JPA sẽ tự động gọi hàm @PreUpdate để sửa ngày updatedAt)
        taskRepository.save(existingTask);

        return "redirect:/tasks/view/" + id;
    }

}