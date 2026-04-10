package com.example.controller;

import com.example.model.Contact;
import com.example.model.Customer;
import com.example.repository.ContactRepository;
import com.example.repository.CustomerRepository;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/search")
@RequiredArgsConstructor
public class SearchApi {

    private final ContactRepository contactRepository;
    private final CustomerRepository customerRepository;

    // API 1: Phục vụ thanh tìm kiếm (Select2)
    @GetMapping("/related")
    public List<Map<String, Object>> searchRelatedObjects(
            @RequestParam("type") String type,
            @RequestParam(value = "q", defaultValue = "") String keyword) {

        List<Map<String, Object>> results = new ArrayList<>();

        if ("CUSTOMER".equals(type)) {
            List<Customer> list = customerRepository.findByNameContainingIgnoreCase(keyword);
            for (Customer c : list) {
                Map<String, Object> item = new HashMap<>();
                item.put("id", c.getId());
                item.put("text", c.getName());
                results.add(item);
            }
        }
        // Nếu người dùng chọn loại là CONTACT
        if ("CONTACT".equals(type)) {
            // Lấy dữ liệu thật từ database
            List<Contact> list = contactRepository.findByFullNameContainingIgnoreCase(keyword);

            for (Contact c : list) {
                Map<String, Object> item = new HashMap<>();
                item.put("id", c.getId()); // Select2 cần id
                item.put("text", c.getFullName()); // Select2 cần text để hiển thị tên
                results.add(item);
            }
        }
        // Sau này có DEAL, CAMPAIGN... bạn chỉ cần thêm else if tương tự

        return results;
    }

    // API 2: Lọc danh sách liên hệ theo ID Công ty (Phục vụ Dependent Dropdown)
    @GetMapping("/contacts-by-customer")
    public List<Map<String, Object>> getContactsByCustomer(@RequestParam("customerId") Long customerId) {
        List<Contact> contacts = contactRepository.findByCustomerId(customerId);
        List<Map<String, Object>> results = new ArrayList<>();

        for (Contact c : contacts) {
            Map<String, Object> map = new HashMap<>();
            map.put("id", c.getId());
            map.put("text", c.getFullName() + (c.getPosition() != null ? " - " + c.getPosition() : "")); // Hiển thị
                                                                                                         // thêm chức vụ
                                                                                                         // cho ngầu
            results.add(map);
        }
        return results;
    }
}