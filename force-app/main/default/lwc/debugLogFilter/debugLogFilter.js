import { LightningElement, track } from 'lwc';

const STATUS_OPTIONS = [
    { label: '-- All --',  value: '' },
    { label: 'Success',    value: 'Success' },
    { label: 'Problem',    value: 'Problem' }
];

export default class DebugLogFilter extends LightningElement {

    @track userId    = '';
    @track operation = '';
    @track status    = '';

    get statusOptions() { return STATUS_OPTIONS; }

    handleUserIdChange(evt)    { this.userId    = evt.target.value; }
    handleOperationChange(evt) { this.operation = evt.target.value; }
    handleStatusChange(evt)    { this.status    = evt.detail.value; }

    handleApply() {
        this.dispatchEvent(new CustomEvent('filterchange', {
            detail: {
                userId:    this.userId.trim()    || null,
                operation: this.operation.trim() || null,
                status:    this.status           || null
            }
        }));
    }

    handleClear() {
        this.userId    = '';
        this.operation = '';
        this.status    = '';
        this.dispatchEvent(new CustomEvent('filterchange', {
            detail: { userId: null, operation: null, status: null }
        }));
    }
}
