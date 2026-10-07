package com.cloudnotes.repository;

import com.cloudnotes.model.Note;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NoteRepository extends JpaRepository<Note, Long> {

    List<Note> findAllByOrderByUpdatedAtDesc();

    List<Note> findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByUpdatedAtDesc(
            String titleQuery, String contentQuery);
}
