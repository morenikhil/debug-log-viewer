import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLogBody from '@salesforce/apex/DebugLogViewerController.getLogBody';

// Log event categories present in Apex debug logs
const CATEGORIES = [
    { label: '-- All Lines --',     value: '' },
    { label: 'USER_DEBUG',          value: 'USER_DEBUG' },
    { label: 'SOQL_EXECUTE_BEGIN',  value: 'SOQL_EXECUTE_BEGIN' },
    { label: 'DML_BEGIN',           value: 'DML_BEGIN' },
    { label: 'EXCEPTION_THROWN',    value: 'EXCEPTION_THROWN' },
    { label: 'FATAL_ERROR',         value: 'FATAL_ERROR' },
    { label: 'CALLOUT_REQUEST',     value: 'CALLOUT_REQUEST' },
    { label: 'CALLOUT_RESPONSE',    value: 'CALLOUT_RESPONSE' },
    { label: 'ENTERING_MANAGED_PKG',value: 'ENTERING_MANAGED_PKG' },
    { label: 'HEAP_ALLOCATE',       value: 'HEAP_ALLOCATE' }
];

export default class DebugLogDetail extends LightningElement {

    @api logId;

    @track isLoading   = false;
    @track errorMessage = null;
    @track rawBody     = '';
    @track searchTerm  = '';
    @track categoryFilter = '';

    get categoryOptions() { return CATEGORIES; }
    get hasBody()  { return !!this.rawBody; }
    get isSearching() { return !!(this.searchTerm || this.categoryFilter); }

    // ─── Filtered body ────────────────────────────────────────────────────────

    get filteredBody() {
        let lines = this.rawBody.split('\n');

        if (this.categoryFilter) {
            lines = lines.filter(l => l.includes(this.categoryFilter));
        }
        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            lines = lines.filter(l => l.toLowerCase().includes(term));
        }
        return lines.join('\n') || '(no lines matched)';
    }

    get matchCount() {
        if (!this.isSearching) return 0;
        return this.filteredBody === '(no lines matched)'
            ? 0
            : this.filteredBody.split('\n').length;
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        if (this.logId) this.loadBody();
    }

    // ─── Data Loading ─────────────────────────────────────────────────────────

    async loadBody() {
        this.isLoading    = true;
        this.errorMessage = null;
        try {
            const result = await getLogBody({ logId: this.logId });
            if (result.errorMessage) {
                this.errorMessage = result.errorMessage;
            } else {
                this.rawBody = result.body ?? '';
            }
        } catch (err) {
            this.errorMessage = err?.body?.message ?? err?.message ?? 'Failed to load log body.';
        } finally {
            this.isLoading = false;
        }
    }

    // ─── Event Handlers ───────────────────────────────────────────────────────

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSearchChange(evt) {
        this.searchTerm = evt.target.value;
    }

    handleCategoryChange(evt) {
        this.categoryFilter = evt.detail.value;
    }

    handleCopy() {
        const content = this.isSearching ? this.filteredBody : this.rawBody;
        navigator.clipboard.writeText(content)
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Copied',
                    message: 'Log content copied to clipboard.',
                    variant: 'success'
                }));
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Copy failed',
                    message: 'Could not copy to clipboard.',
                    variant: 'warning'
                }));
            });
    }

    handleDownload() {
        const content  = this.isSearching ? this.filteredBody : this.rawBody;
        const blob     = new Blob([content], { type: 'text/plain' });
        const url      = URL.createObjectURL(blob);
        const anchor   = document.createElement('a');
        anchor.href    = url;
        anchor.download = `ApexLog_${this.logId}.log`;
        anchor.click();
        URL.revokeObjectURL(url);
    }
}
