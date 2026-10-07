/**
 * CloudNotes Frontend Application
 * Interacts with Spring Boot REST API (/api/notes) and Actuator (/actuator/health)
 */

document.addEventListener('DOMContentLoaded', () => {
    // DOM Elements
    const notesGrid = document.getElementById('notesGrid');
    const notesCount = document.getElementById('notesCount');
    const emptyState = document.getElementById('emptyState');
    const loadingIndicator = document.getElementById('loadingIndicator');
    const searchInput = document.getElementById('searchInput');
    const btnClearSearch = document.getElementById('btnClearSearch');
    const btnNewNote = document.getElementById('btnNewNote');
    const btnEmptyCreate = document.getElementById('btnEmptyCreate');

    // Health badge
    const healthBadge = document.getElementById('healthBadge');
    const healthText = document.getElementById('healthText');

    // Note Modal
    const noteModal = document.getElementById('noteModal');
    const modalTitle = document.getElementById('modalTitle');
    const noteForm = document.getElementById('noteForm');
    const noteIdInput = document.getElementById('noteId');
    const noteTitleInput = document.getElementById('noteTitle');
    const noteContentInput = document.getElementById('noteContent');
    const btnModalClose = document.getElementById('btnModalClose');
    const btnModalCancel = document.getElementById('btnModalCancel');
    const titleError = document.getElementById('titleError');
    const contentError = document.getElementById('contentError');

    // Delete Modal
    const deleteModal = document.getElementById('deleteModal');
    const btnDeleteClose = document.getElementById('btnDeleteClose');
    const btnDeleteCancel = document.getElementById('btnDeleteCancel');
    const btnDeleteConfirm = document.getElementById('btnDeleteConfirm');

    // State
    let notes = [];
    let noteToDeleteId = null;
    let searchDebounceTimer = null;

    // Initialize
    loadNotes();
    checkHealth();
    setInterval(checkHealth, 30000); // Check health every 30s

    // Event Listeners
    btnNewNote.addEventListener('click', () => openNoteModal());
    btnEmptyCreate.addEventListener('click', () => openNoteModal());
    btnModalClose.addEventListener('click', closeNoteModal);
    btnModalCancel.addEventListener('click', closeNoteModal);
    noteForm.addEventListener('submit', handleNoteFormSubmit);

    btnDeleteClose.addEventListener('click', closeDeleteModal);
    btnDeleteCancel.addEventListener('click', closeDeleteModal);
    btnDeleteConfirm.addEventListener('click', handleConfirmDelete);

    searchInput.addEventListener('input', (e) => {
        const query = e.target.value.trim();
        btnClearSearch.classList.toggle('hidden', query.length === 0);

        clearTimeout(searchDebounceTimer);
        searchDebounceTimer = setTimeout(() => {
            loadNotes(query);
        }, 250);
    });

    btnClearSearch.addEventListener('click', () => {
        searchInput.value = '';
        btnClearSearch.classList.add('hidden');
        loadNotes('');
    });

    // Close modals on Escape key
    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeNoteModal();
            closeDeleteModal();
        }
    });

    // Close modals on backdrop click
    [noteModal, deleteModal].forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                closeNoteModal();
                closeDeleteModal();
            }
        });
    });

    /**
     * Fetch notes from backend API
     */
    async function loadNotes(query = '') {
        try {
            showLoading(true);
            const url = query ? `/api/notes?search=${encodeURIComponent(query)}` : '/api/notes';
            const response = await fetch(url);

            if (!response.ok) {
                throw new Error(`Failed to fetch notes: ${response.statusText}`);
            }

            notes = await response.json();
            renderNotes(notes, query);
        } catch (error) {
            console.error('Error loading notes:', error);
            showToast(error.message || 'Error connecting to CloudNotes backend', 'error');
            renderNotes([], query);
        } finally {
            showLoading(false);
        }
    }

    /**
     * Render note cards in the grid
     */
    function renderNotes(items, query = '') {
        notesGrid.innerHTML = '';
        notesCount.textContent = `${items.length} ${items.length === 1 ? 'note' : 'notes'}`;

        if (items.length === 0) {
            emptyState.classList.remove('hidden');
            const subtitle = document.getElementById('emptyStateSubtitle');
            if (query) {
                subtitle.textContent = `No notes match "${query}". Try searching for something else.`;
            } else {
                subtitle.textContent = 'Capture your thoughts, architecture notes, and deployment ideas.';
            }
            return;
        }

        emptyState.classList.add('hidden');

        items.forEach(note => {
            const card = document.createElement('article');
            card.className = 'note-card';
            card.dataset.id = note.id;

            const formattedDate = formatDate(note.updatedAt || note.createdAt);

            card.innerHTML = `
                <div class="note-header">
                    <h3 class="note-title">${escapeHtml(note.title)}</h3>
                </div>
                <div class="note-body">${escapeHtml(note.content)}</div>
                <div class="note-footer">
                    <span class="note-timestamp" title="Last updated">${formattedDate}</span>
                    <div class="note-actions">
                        <button class="action-btn edit-btn" data-id="${note.id}" aria-label="Edit note">Edit</button>
                        <button class="action-btn delete delete-btn" data-id="${note.id}" aria-label="Delete note">Delete</button>
                    </div>
                </div>
            `;

            // Attach action handlers
            card.querySelector('.edit-btn').addEventListener('click', () => openNoteModal(note));
            card.querySelector('.delete-btn').addEventListener('click', () => openDeleteModal(note.id));

            notesGrid.appendChild(card);
        });
    }

    /**
     * Handle Form Submission (Create or Update)
     */
    async function handleNoteFormSubmit(e) {
        e.preventDefault();
        clearFormErrors();

        const id = noteIdInput.value;
        const title = noteTitleInput.value.trim();
        const content = noteContentInput.value.trim();

        let hasError = false;
        if (!title) {
            titleError.textContent = 'Title is required';
            hasError = true;
        }
        if (!content) {
            contentError.textContent = 'Content is required';
            hasError = true;
        }
        if (hasError) return;

        const payload = { title, content };
        const isEditing = Boolean(id);
        const url = isEditing ? `/api/notes/${id}` : '/api/notes';
        const method = isEditing ? 'PUT' : 'POST';

        try {
            const response = await fetch(url, {
                method,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            if (!response.ok) {
                const errData = await response.json().catch(() => null);
                throw new Error(errData?.message || `Failed to save note: ${response.status}`);
            }

            closeNoteModal();
            showToast(isEditing ? 'Note updated successfully' : 'Note created successfully', 'success');
            loadNotes(searchInput.value.trim());
        } catch (error) {
            console.error('Save error:', error);
            showToast(error.message, 'error');
        }
    }

    /**
     * Delete Note confirmation
     */
    async function handleConfirmDelete() {
        if (!noteToDeleteId) return;

        try {
            const response = await fetch(`/api/notes/${noteToDeleteId}`, {
                method: 'DELETE'
            });

            if (!response.ok && response.status !== 204) {
                throw new Error(`Failed to delete note: ${response.status}`);
            }

            closeDeleteModal();
            showToast('Note deleted', 'success');
            loadNotes(searchInput.value.trim());
        } catch (error) {
            console.error('Delete error:', error);
            showToast(error.message, 'error');
        }
    }

    /**
     * Actuator Health Check
     */
    async function checkHealth() {
        try {
            const res = await fetch('/actuator/health');
            if (res.ok) {
                const data = await res.json();
                const dbStatus = data.components?.db?.status || 'UP';
                healthBadge.className = 'health-badge healthy';
                healthText.textContent = `Cloud API: UP (DB: ${dbStatus})`;
            } else {
                healthBadge.className = 'health-badge down';
                healthText.textContent = 'Service Degraded';
            }
        } catch (err) {
            healthBadge.className = 'health-badge down';
            healthText.textContent = 'Connecting...';
        }
    }

    // Modal Helpers
    function openNoteModal(note = null) {
        clearFormErrors();
        if (note) {
            modalTitle.textContent = 'Edit Note';
            noteIdInput.value = note.id;
            noteTitleInput.value = note.title;
            noteContentInput.value = note.content;
        } else {
            modalTitle.textContent = 'Create New Note';
            noteIdInput.value = '';
            noteTitleInput.value = '';
            noteContentInput.value = '';
        }
        noteModal.classList.remove('hidden');
        setTimeout(() => noteTitleInput.focus(), 50);
    }

    function closeNoteModal() {
        noteModal.classList.add('hidden');
        clearFormErrors();
    }

    function openDeleteModal(id) {
        noteToDeleteId = id;
        deleteModal.classList.remove('hidden');
    }

    function closeDeleteModal() {
        noteToDeleteId = null;
        deleteModal.classList.add('hidden');
    }

    function clearFormErrors() {
        titleError.textContent = '';
        contentError.textContent = '';
    }

    function showLoading(show) {
        loadingIndicator.classList.toggle('hidden', !show);
        if (show) {
            emptyState.classList.add('hidden');
        }
    }

    function showToast(message, type = 'info') {
        const container = document.getElementById('toastContainer');
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.textContent = message;

        container.appendChild(toast);
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(10px)';
            toast.style.transition = 'all 0.3s ease';
            setTimeout(() => toast.remove(), 300);
        }, 3500);
    }

    function formatDate(dateString) {
        if (!dateString) return '';
        try {
            const date = new Date(dateString);
            return date.toLocaleDateString(undefined, {
                month: 'short',
                day: 'numeric',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch {
            return dateString;
        }
    }

    function escapeHtml(str) {
        if (!str) return '';
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }
});
