package com.cloudnotes;

import com.cloudnotes.dto.NoteRequest;
import com.cloudnotes.dto.NoteResponse;
import com.cloudnotes.repository.NoteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.*;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class CloudNotesIntegrationTest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private NoteRepository noteRepository;

    private String getBaseUrl() {
        return "http://localhost:" + port + "/api/notes";
    }

    @BeforeEach
    void cleanUp() {
        noteRepository.deleteAll();
    }

    @Test
    @DisplayName("Complete Note lifecycle: Create -> Get -> Update -> Delete")
    void testCompleteNoteLifecycle() {
        // 1. Create Note
        NoteRequest createRequest = new NoteRequest("Architecture Review", "Discuss multi-tier VPC configuration.");
        ResponseEntity<NoteResponse> createResponse = restTemplate.postForEntity(
                getBaseUrl(), createRequest, NoteResponse.class);

        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(createResponse.getBody()).isNotNull();
        Long noteId = createResponse.getBody().id();
        assertThat(noteId).isNotNull();
        assertThat(createResponse.getBody().title()).isEqualTo("Architecture Review");

        // 2. Read Note
        ResponseEntity<NoteResponse> getResponse = restTemplate.getForEntity(
                getBaseUrl() + "/" + noteId, NoteResponse.class);
        assertThat(getResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(getResponse.getBody()).isNotNull();
        assertThat(getResponse.getBody().content()).isEqualTo("Discuss multi-tier VPC configuration.");

        // 3. Update Note
        NoteRequest updateRequest = new NoteRequest("Architecture Review Final", "VPC and RDS security groups verified.");
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<NoteRequest> updateEntity = new HttpEntity<>(updateRequest, headers);

        ResponseEntity<NoteResponse> updateResponse = restTemplate.exchange(
                getBaseUrl() + "/" + noteId, HttpMethod.PUT, updateEntity, NoteResponse.class);

        assertThat(updateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(updateResponse.getBody()).isNotNull();
        assertThat(updateResponse.getBody().title()).isEqualTo("Architecture Review Final");
        assertThat(updateResponse.getBody().content()).isEqualTo("VPC and RDS security groups verified.");

        // 4. Delete Note
        ResponseEntity<Void> deleteResponse = restTemplate.exchange(
                getBaseUrl() + "/" + noteId, HttpMethod.DELETE, null, Void.class);
        assertThat(deleteResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        // 5. Verify Not Found
        ResponseEntity<String> getAfterDelete = restTemplate.getForEntity(
                getBaseUrl() + "/" + noteId, String.class);
        assertThat(getAfterDelete.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @DisplayName("Actuator health endpoint should return UP")
    void testActuatorHealth() {
        ResponseEntity<String> healthResponse = restTemplate.getForEntity(
                "http://localhost:" + port + "/actuator/health", String.class);
        assertThat(healthResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(healthResponse.getBody()).contains("\"status\":\"UP\"");
    }
}
