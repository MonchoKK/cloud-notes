package com.cloudnotes.service;

import com.cloudnotes.dto.NoteRequest;
import com.cloudnotes.dto.NoteResponse;
import com.cloudnotes.exception.ResourceNotFoundException;
import com.cloudnotes.model.Note;
import com.cloudnotes.repository.NoteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NoteServiceTest {

    @Mock
    private NoteRepository noteRepository;

    @InjectMocks
    private NoteService noteService;

    private Note sampleNote;

    @BeforeEach
    void setUp() {
        sampleNote = new Note("Cloud Architecture", "Design VPC and RDS subnets");
        sampleNote.setId(1L);
    }

    @Test
    @DisplayName("Should return all notes ordered by updatedAt descending")
    void shouldReturnAllNotes() {
        when(noteRepository.findAllByOrderByUpdatedAtDesc()).thenReturn(List.of(sampleNote));

        List<NoteResponse> result = noteService.getAllNotes(null);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).title()).isEqualTo("Cloud Architecture");
        verify(noteRepository).findAllByOrderByUpdatedAtDesc();
    }

    @Test
    @DisplayName("Should filter notes by search query")
    void shouldFilterNotesByQuery() {
        when(noteRepository.findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByUpdatedAtDesc("VPC", "VPC"))
                .thenReturn(List.of(sampleNote));

        List<NoteResponse> result = noteService.getAllNotes("VPC");

        assertThat(result).hasSize(1);
        assertThat(result.get(0).content()).contains("VPC");
        verify(noteRepository).findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByUpdatedAtDesc("VPC", "VPC");
    }

    @Test
    @DisplayName("Should return note by ID when exists")
    void shouldReturnNoteByIdWhenExists() {
        when(noteRepository.findById(1L)).thenReturn(Optional.of(sampleNote));

        NoteResponse result = noteService.getNoteById(1L);

        assertThat(result.id()).isEqualTo(1L);
        assertThat(result.title()).isEqualTo("Cloud Architecture");
    }

    @Test
    @DisplayName("Should throw ResourceNotFoundException when note does not exist")
    void shouldThrowWhenNoteNotFound() {
        when(noteRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> noteService.getNoteById(99L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Note not found with id: 99");
    }

    @Test
    @DisplayName("Should create and return new note")
    void shouldCreateNote() {
        NoteRequest request = new NoteRequest("Deploy to AWS", "Configure EC2 and ALB");
        Note savedNote = new Note("Deploy to AWS", "Configure EC2 and ALB");
        savedNote.setId(2L);

        when(noteRepository.save(any(Note.class))).thenReturn(savedNote);

        NoteResponse result = noteService.createNote(request);

        assertThat(result.id()).isEqualTo(2L);
        assertThat(result.title()).isEqualTo("Deploy to AWS");
        verify(noteRepository).save(any(Note.class));
    }

    @Test
    @DisplayName("Should update existing note")
    void shouldUpdateExistingNote() {
        NoteRequest request = new NoteRequest("Updated Title", "Updated Content");
        when(noteRepository.findById(1L)).thenReturn(Optional.of(sampleNote));
        when(noteRepository.save(sampleNote)).thenReturn(sampleNote);

        NoteResponse result = noteService.updateNote(1L, request);

        assertThat(result.title()).isEqualTo("Updated Title");
        assertThat(result.content()).isEqualTo("Updated Content");
    }

    @Test
    @DisplayName("Should delete note when exists")
    void shouldDeleteNoteWhenExists() {
        when(noteRepository.existsById(1L)).thenReturn(true);

        noteService.deleteNote(1L);

        verify(noteRepository).deleteById(1L);
    }

    @Test
    @DisplayName("Should throw ResourceNotFoundException when deleting non-existent note")
    void shouldThrowWhenDeletingNonExistentNote() {
        when(noteRepository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> noteService.deleteNote(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
