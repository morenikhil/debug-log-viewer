/**
 * DebugLogViewerController
 * Fetches ApexLog records and log body via Salesforce Tooling API using a Named Credential.
 * Designed for sandbox/developer environments only.
 */
public with sharing class DebugLogViewerController {

    private static final String NAMED_CREDENTIAL = 'callout:SalesforceToolingAPI';
    private static final String TOOLING_API_VERSION = 'v59.0';
    private static final Integer DEFAULT_LIMIT = 50;
    private static final Integer MAX_LIMIT = 200;

    // ─── Inner DTOs ───────────────────────────────────────────────────────────

    public class ApexLogRecord {
        @AuraEnabled public String  id                  { get; set; }
        @AuraEnabled public String  logUserId           { get; set; }
        @AuraEnabled public String  logUserName         { get; set; }
        @AuraEnabled public Integer logLength           { get; set; }
        @AuraEnabled public String  lastModifiedDate    { get; set; }
        @AuraEnabled public String  operation           { get; set; }
        @AuraEnabled public String  request             { get; set; }
        @AuraEnabled public String  status              { get; set; }
        @AuraEnabled public Integer durationMilliseconds{ get; set; }
        @AuraEnabled public String  application         { get; set; }
        @AuraEnabled public String  location            { get; set; }
    }

    public class LogListResult {
        @AuraEnabled public List<ApexLogRecord> records     { get; set; }
        @AuraEnabled public Integer             totalSize   { get; set; }
        @AuraEnabled public Boolean             done        { get; set; }
        @AuraEnabled public String              errorMessage{ get; set; }
    }

    public class LogBodyResult {
        @AuraEnabled public String  id           { get; set; }
        @AuraEnabled public String  body         { get; set; }
        @AuraEnabled public String  errorMessage { get; set; }
    }

    public class DeleteResult {
        @AuraEnabled public Boolean success      { get; set; }
        @AuraEnabled public String  errorMessage { get; set; }
    }

    // ─── Public Apex Methods ──────────────────────────────────────────────────

    /**
     * Retrieves a list of ApexLog records with optional filters.
     *
     * @param userId       Filter by log owner User Id (null = all users)
     * @param operation    Filter by operation keyword (null = all)
     * @param status       Filter by status: 'Success' | 'Problem' (null = all)
     * @param recordLimit  Max rows to return (capped at MAX_LIMIT)
     */
    @AuraEnabled(cacheable=false)
    public static LogListResult getApexLogs(
        String userId,
        String operation,
        String status,
        Integer recordLimit
    ) {
        LogListResult result = new LogListResult();
        try {
            Integer lim = (recordLimit != null && recordLimit > 0)
                ? Math.min(recordLimit, MAX_LIMIT)
                : DEFAULT_LIMIT;

            String soql = buildLogQuery(userId, operation, status, lim);
            String endpoint = NAMED_CREDENTIAL
                + '/services/data/' + TOOLING_API_VERSION
                + '/tooling/query/?q=' + EncodingUtil.urlEncode(soql, 'UTF-8');

            HttpResponse res = makeGetRequest(endpoint);

            if (res.getStatusCode() == 200) {
                Map<String, Object> payload =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.totalSize = (Integer) payload.get('totalSize');
                result.done      = (Boolean) payload.get('done');
                result.records   = parseLogRecords(
                    (List<Object>) payload.get('records')
                );
            } else {
                result.errorMessage = parseApiError(res);
            }
        } catch (Exception ex) {
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    /**
     * Fetches the raw body of a single ApexLog record.
     *
     * @param logId  18-char ApexLog record Id
     */
    @AuraEnabled(cacheable=false)
    public static LogBodyResult getLogBody(String logId) {
        LogBodyResult result = new LogBodyResult();
        result.id = logId;
        try {
            validateLogId(logId);

            String endpoint = NAMED_CREDENTIAL
                + '/services/data/' + TOOLING_API_VERSION
                + '/tooling/sobjects/ApexLog/' + logId + '/Body';

            HttpResponse res = makeGetRequest(endpoint);

            if (res.getStatusCode() == 200) {
                result.body = res.getBody();
            } else {
                result.errorMessage = parseApiError(res);
            }
        } catch (Exception ex) {
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    /**
     * Deletes one or more ApexLog records by Id.
     *
     * @param logIds  List of ApexLog record Ids to delete
     */
    @AuraEnabled(cacheable=false)
    public static DeleteResult deleteApexLogs(List<String> logIds) {
        DeleteResult result = new DeleteResult();
        try {
            if (logIds == null || logIds.isEmpty()) {
                result.success = true;
                return result;
            }
            for (String logId : logIds) {
                validateLogId(logId);
            }
            String ids = String.join(logIds, ',');
            String endpoint = NAMED_CREDENTIAL
                + '/services/data/' + TOOLING_API_VERSION
                + '/tooling/composite/sobjects?ids=' + ids;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('DELETE');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 204) {
                result.success = true;
            } else {
                result.success = false;
                result.errorMessage = parseApiError(res);
            }
        } catch (Exception ex) {
            result.success = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    private static String buildLogQuery(
        String userId,
        String operation,
        String status,
        Integer lim
    ) {
        List<String> conditions = new List<String>();

        if (String.isNotBlank(userId)) {
            conditions.add('LogUserId = \'' + String.escapeSingleQuotes(userId) + '\'');
        }
        if (String.isNotBlank(operation)) {
            conditions.add(
                'Operation LIKE \'%' + String.escapeSingleQuotes(operation) + '%\''
            );
        }
        if (String.isNotBlank(status)) {
            conditions.add('Status = \'' + String.escapeSingleQuotes(status) + '\'');
        }

        String query =
            'SELECT Id, LogUserId, LogUser.Name, LogLength, LastModifiedDate, '
            + 'Operation, Request, Status, DurationMilliseconds, Application, Location '
            + 'FROM ApexLog';

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        query += ' ORDER BY LastModifiedDate DESC LIMIT ' + lim;
        return query;
    }

    private static HttpResponse makeGetRequest(String endpoint) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);
        return new Http().send(req);
    }

    private static List<ApexLogRecord> parseLogRecords(List<Object> rawRecords) {
        List<ApexLogRecord> logs = new List<ApexLogRecord>();
        if (rawRecords == null) return logs;

        for (Object obj : rawRecords) {
            Map<String, Object> rec = (Map<String, Object>) obj;
            ApexLogRecord log = new ApexLogRecord();
            log.id                   = (String)  rec.get('Id');
            log.logUserId            = (String)  rec.get('LogUserId');
            log.logLength            = (Integer) rec.get('LogLength');
            log.operation            = (String)  rec.get('Operation');
            log.request              = (String)  rec.get('Request');
            log.status               = (String)  rec.get('Status');
            log.durationMilliseconds = (Integer) rec.get('DurationMilliseconds');
            log.application          = (String)  rec.get('Application');
            log.location             = (String)  rec.get('Location');
            log.lastModifiedDate     = (String)  rec.get('LastModifiedDate');

            Object logUser = rec.get('LogUser');
            if (logUser != null) {
                Map<String, Object> userMap = (Map<String, Object>) logUser;
                log.logUserName = (String) userMap.get('Name');
            }
            logs.add(log);
        }
        return logs;
    }

    private static String parseApiError(HttpResponse res) {
        try {
            List<Object> errors = (List<Object>) JSON.deserializeUntyped(res.getBody());
            if (!errors.isEmpty()) {
                Map<String, Object> err = (Map<String, Object>) errors[0];
                return (String) err.get('message');
            }
        } catch (Exception ex) {
            // fall through to raw body
        }
        return 'HTTP ' + res.getStatusCode() + ': ' + res.getBody();
    }

    private static void validateLogId(String logId) {
        if (String.isBlank(logId) || !logId.startsWith('07L')) {
            throw new AuraHandledException(
                'Invalid ApexLog record Id: ' + logId
            );
        }
    }
}
