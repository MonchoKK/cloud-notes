package com.cloudnotes;

import com.cloudnotes.model.Note;
import com.cloudnotes.repository.NoteRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Profile;

@SpringBootApplication
public class CloudNotesApplication {

    public static void main(String[] args) {
        SpringApplication.run(CloudNotesApplication.class, args);
    }

    @Bean
    @Profile("dev")
    public CommandLineRunner seedDevData(NoteRepository noteRepository) {
        return args -> {
            if (noteRepository.count() == 0) {
                noteRepository.save(new Note(
                    "☁️ Welcome to CloudNotes",
                    "CloudNotes is running with an in-memory database. You can create, edit, and delete notes in real time!"
                ));
                noteRepository.save(new Note(
                    "🔒 Cloud Security & Networking",
                    "In production, CloudNotes connects to an Amazon RDS PostgreSQL database residing in private subnets with least-privilege security groups."
                ));
            }
        };
    }
}

