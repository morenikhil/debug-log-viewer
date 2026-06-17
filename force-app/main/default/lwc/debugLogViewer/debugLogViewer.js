import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getApexLogs   from '@salesforce/apex/DebugLogViewerController.getApexLogs';
import deleteApexLogs from '@salesforce/apex/DebugLogViewerController.deleteApexLogs';

const DEFAULT_LIMIT = 50;
const LOAD_MORE_STEP = 50;

export default class DebugLogViewer extends LightningElement {

    // ─── Reactive State ───────────────────────────────────────────────────────
    @track logs          = [];
    @track isLoading     = false;
    @track isLoadingMore = false;
    @track isDeleting    = false;
    @track errorMessage  = null;
    @track isDetailOpen  = false;
    @track isDeleteConfirmOpen = false;

    selectedLogId = null;
    totalSize     = 0;
    currentLimit  = DEFAULT_LIMIT;
    sortField     = 'lastModifiedDate';
    sortAscending = false;

    // active filter values
    filterUserId    = null;
    filterOperation = null;
    filterStatus    = null;

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadLogs();
    }

    // ─── Computed Properties ──────────────────────────────────────────────────

    get hasLogs()        { return this.logs.length > 0; }
    get displayedCount() { return this.logs.length; }
    get hasNoSelection() { return this.selectedCount === 0 || this.isDeleting; }
    get canLoadMore()    { return this.logs.length < this.totalSize; }
    get isSortedByDate() { return this.sortField === 'lastModifiedDate'; }
    get sortIconName()   { return this.sortAscending ? 'utility:arrowup' : 'utility:arrowdown'; }

    get selectedCount() {
        return this.logs.filter(l => l.selected).length;
    }

    get allSelected() {
        return this.logs.length > 0 && this.logs.every(l => l.selected);
    }

    get sortedLogs() {
        const field = this.sortField;
        const asc   = this.sortAscending ? 1 : -1;
        return [...this.logs].sort((a, b) => {
            const va = a[field] ?? '';
            const vb = b[field] ?? '';
            if (va < vb) return -asc;
            if (va > vb) return  asc;
            return 0;
        });
    }

    // ─── Data Loading ─────────────────────────────────────────────────────────

    async loadLogs(append = false) {
        if (append) {
            this.isLoadingMore = true;
        } else {
            this.isLoading = true;
            this.logs = [];
        }
        this.errorMessage = null;

        try {
            const result = await getApexLogs({
                userId:      this.filterUserId,
                operation:   this.filterOperation,
                status:      this.filterStatus,
                recordLimit: this.currentLimit
            });

            if (result.errorMessage) {
                this.errorMessage = result.errorMessage;
            } else {
                this.totalSize = result.totalSize ?? 0;
                const enriched = (result.records ?? []).map(r => this.enrichRecord(r));
                this.logs = append
                    ? [...this.logs, ...enriched]
                    : enriched;
            }
        } catch (err) {
            this.errorMessage = this.extractError(err);
        } finally {
            this.isLoading     = false;
            this.isLoadingMore = false;
        }
    }

    enrichRecord(rec) {
        return {
            ...rec,
            selected:      false,
            formattedDate: rec.lastModifiedDate
                ? new Date(rec.lastModifiedDate).toLocaleString()
                : '—',
            rowClass:  'dlv-log-row',
            statusClass: rec.status === 'Success'
                ? 'dlv-badge-success'
                : 'dlv-badge-error'
        };
    }

    // ─── Event Handlers ───────────────────────────────────────────────────────

    handleFilterChange(evt) {
        const { userId, operation, status } = evt.detail;
        this.filterUserId    = userId    || null;
        this.filterOperation = operation || null;
        this.filterStatus    = status    || null;
        this.currentLimit    = DEFAULT_LIMIT;
        this.loadLogs();
    }

    handleRefresh() {
        this.currentLimit = DEFAULT_LIMIT;
        this.loadLogs();
    }

    handleLoadMore() {
        this.currentLimit += LOAD_MORE_STEP;
        this.loadLogs(true);
    }

    handleSort(evt) {
        const field = evt.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortAscending = !this.sortAscending;
        } else {
            this.sortField    = field;
            this.sortAscending = false;
        }
    }

    handleRowClick(evt) {
        const logId = evt.currentTarget.dataset.id;
        if (logId) {
            this.selectedLogId = logId;
            this.isDetailOpen  = true;
        }
    }

    handleRowSelect(evt) {
        const id      = evt.target.dataset.id;
        const checked = evt.target.checked;
        this.logs = this.logs.map(l =>
            l.id === id ? { ...l, selected: checked } : l
        );
    }

    handleSelectAll(evt) {
        const checked = evt.target.checked;
        this.logs = this.logs.map(l => ({ ...l, selected: checked }));
    }

    handleViewLog(evt) {
        this.selectedLogId = evt.currentTarget.dataset.id;
        this.isDetailOpen  = true;
    }

    handleDetailClose() {
        this.isDetailOpen  = false;
        this.selectedLogId = null;
    }

    handleDeleteSelected() {
        if (this.selectedCount > 0) {
            this.isDeleteConfirmOpen = true;
        }
    }

    handleDeleteCancel() {
        this.isDeleteConfirmOpen = false;
    }

    async handleDeleteConfirm() {
        this.isDeleting = true;
        const ids = this.logs.filter(l => l.selected).map(l => l.id);

        try {
            const result = await deleteApexLogs({ logIds: ids });
            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Deleted',
                    message: `${ids.length} log(s) deleted successfully.`,
                    variant: 'success'
                }));
                this.isDeleteConfirmOpen = false;
                this.loadLogs();
            } else {
                this.errorMessage = result.errorMessage;
                this.isDeleteConfirmOpen = false;
            }
        } catch (err) {
            this.errorMessage = this.extractError(err);
            this.isDeleteConfirmOpen = false;
        } finally {
            this.isDeleting = false;
        }
    }

    clearError() {
        this.errorMessage = null;
    }

    stopPropagation(evt) {
        evt.stopPropagation();
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    extractError(err) {
        if (typeof err === 'string')               return err;
        if (err?.body?.message)                    return err.body.message;
        if (err?.body?.pageErrors?.[0]?.message)   return err.body.pageErrors[0].message;
        if (err?.message)                          return err.message;
        return 'An unexpected error occurred.';
    }
}
