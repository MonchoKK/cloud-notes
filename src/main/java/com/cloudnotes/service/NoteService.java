package com.cloudnotes.service;

import com.cloudnotes.dto.NoteRequest;
import com.cloudnotes.dto.NoteResponse;
import com.cloudnotes.exception.ResourceNotFoundException;
import com.cloudnotes.model.Note;
import com.cloudnotes.repository.NoteRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class NoteService {

    private final NoteRepository noteRepository;

    public NoteService(NoteRepository noteRepository) {
        this.noteRepository = noteRepository;
    }

    @Transactional(readOnly = true)
    public List<NoteResponse> getAllNotes(String query) {
        List<Note> notes;
        if (query != null && !query.trim().isEmpty()) {
            String trimmed = query.trim();
            notes = noteRepository.findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByUpdatedAtDesc(trimmed, trimmed);
        } else {
            notes = noteRepository.findAllByOrderByUpdatedAtDesc();
        }
        return notes.stream()
                .map(NoteResponse::fromEntity)
                .toList();
    }

    @Transactional(readOnly = true)
    public NoteResponse getNoteById(Long id) {
        Note note = noteRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Note", id));
        return NoteResponse.fromEntity(note);
    }

    public NoteResponse createNote(NoteRequest request) {
        Note note = new Note(request.title().trim(), request.content().trim());
        Note saved = noteRepository.save(note);
        return NoteResponse.fromEntity(saved);
    }

    public NoteResponse updateNote(Long id, NoteRequest request) {
        Note note = noteRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Note", id));

        note.setTitle(request.title().trim());
        note.setContent(request.content().trim());
        Note updated = noteRepository.save(note);
        return NoteResponse.fromEntity(updated);
    }

    public void deleteNote(Long id) {
        if (!noteRepository.existsById(id)) {
            throw new ResourceNotFoundException("Note", id);
        }
        noteRepository.deleteById(id);
    }
}
