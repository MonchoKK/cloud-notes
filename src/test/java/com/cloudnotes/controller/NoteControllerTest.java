package com.cloudnotes.controller;

import com.cloudnotes.dto.NoteRequest;
import com.cloudnotes.dto.NoteResponse;
import com.cloudnotes.exception.ResourceNotFoundException;
import com.cloudnotes.service.NoteService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;

import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(NoteController.class)
class NoteControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private NoteService noteService;

    private final NoteResponse sampleResponse = new NoteResponse(
            1L,
            "Terraform Plan",
            "Define RDS and VPC in HCL",
            LocalDateTime.now(),
            LocalDateTime.now()
    );

    @Test
    @DisplayName("GET /api/notes - Should return list of notes")
    void shouldReturnAllNotes() throws Exception {
        when(noteService.getAllNotes(null)).thenReturn(List.of(sampleResponse));

        mockMvc.perform(get("/api/notes"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id", is(1)))
                .andExpect(jsonPath("$[0].title", is("Terraform Plan")));
    }

    @Test
    @DisplayName("GET /api/notes/{id} - Should return note when found")
    void shouldReturnNoteById() throws Exception {
        when(noteService.getNoteById(1L)).thenReturn(sampleResponse);

        mockMvc.perform(get("/api/notes/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id", is(1)))
                .andExpect(jsonPath("$.title", is("Terraform Plan")));
    }

    @Test
    @DisplayName("GET /api/notes/{id} - Should return 404 when note not found")
    void shouldReturn404WhenNotFound() throws Exception {
        when(noteService.getNoteById(99L)).thenThrow(new ResourceNotFoundException("Note", 99L));

        mockMvc.perform(get("/api/notes/99"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status", is(404)))
                .andExpect(jsonPath("$.message", is("Note not found with id: 99")));
    }

    @Test
    @DisplayName("POST /api/notes - Should create note and return 201 Created")
    void shouldCreateNote() throws Exception {
        NoteRequest request = new NoteRequest("New Note", "Content for new note");
        when(noteService.createNote(any(NoteRequest.class))).thenReturn(sampleResponse);

        mockMvc.perform(post("/api/notes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.title", is("Terraform Plan")));
    }

    @Test
    @DisplayName("POST /api/notes - Should return 400 Bad Request when validation fails")
    void shouldReturn400WhenPayloadInvalid() throws Exception {
        NoteRequest invalidRequest = new NoteRequest("", "");

        mockMvc.perform(post("/api/notes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status", is(400)));
    }

    @Test
    @DisplayName("PUT /api/notes/{id} - Should update note")
    void shouldUpdateNote() throws Exception {
        NoteRequest updateRequest = new NoteRequest("Updated", "Updated content");
        when(noteService.updateNote(eq(1L), any(NoteRequest.class))).thenReturn(sampleResponse);

        mockMvc.perform(put("/api/notes/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id", is(1)));
    }

    @Test
    @DisplayName("DELETE /api/notes/{id} - Should return 204 No Content")
    void shouldDeleteNote() throws Exception {
        doNothing().when(noteService).deleteNote(1L);

        mockMvc.perform(delete("/api/notes/1"))
                .andExpect(status().isNoContent());

        verify(noteService).deleteNote(1L);
    }
}
