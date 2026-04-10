package com.example.repository;
import java.util.List;

import com.example.model.Contact;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ContactRepository extends JpaRepository<Contact, Long> {
    List<Contact> findByFullNameContainingIgnoreCase(String keyword);

    List<Contact> findByCustomerId(Long customerId);
}