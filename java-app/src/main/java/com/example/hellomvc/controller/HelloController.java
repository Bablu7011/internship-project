package com.example.hellomvc.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HelloController {

    @GetMapping("/")
    public String hello(Model model) {
        model.addAttribute("message", "Auto Scaling Works!");
        return "hello"; // This renders hello.html
    }

    // ADD THIS NEW METHOD
    @GetMapping("/health")
    public ResponseEntity<String> healthCheck() {
        // This endpoint does nothing but return a 200 OK status.
        return ResponseEntity.ok("OK");
    }
}