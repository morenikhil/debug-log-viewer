/**
 * DebugLogViewerControllerTest
 * Unit tests for DebugLogViewerController using mock HTTP callouts.
 * Target coverage: ≥ 85%
 */
@IsTest
private class DebugLogViewerControllerTest {

    // ─── Mock Callout Implementations ────────────────────────────────────────

    private class MockLogListSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{'
                + '"totalSize":1,'
                + '"done":true,'
                + '"records":[{'
                +   '"Id":"07L000000000001AAA",'
                +   '"LogUserId":"005000000000001AAA",'
                +   '"LogUser":{"Name":"Test User"},'
                +   '"LogLength":12345,'
                +   '"LastModifiedDate":"2024-01-15T10:30:00.000Z",'
                +   '"Operation":"execute_anonymous_apex",'
                +   '"Request":"AnonymousApex",'
                +   '"Status":"Success",'
                +   '"DurationMilliseconds":350,'
                +   '"Application":"Unknown",'
                +   '"Location":"Unknown"'
                + '}]'
                + '}');
            return res;
        }
    }

    private class MockLogBodySuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/plain');
            res.setBody('51.0 APEX_CODE,DEBUG;APEX_PROFILING,INFO\n'
                + '16:30:00.000 (1234567)|USER_DEBUG|[1]|DEBUG|Hello World\n'
                + '16:30:00.001 (1234568)|SOQL_EXECUTE_BEGIN|[2]|SELECT Id FROM Account LIMIT 1\n');
            return res;
        }
    }

    private class MockDeleteSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }

    private class MockApiError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('[{"message":"MALFORMED_QUERY","errorCode":"MALFORMED_QUERY"}]');
            return res;
        }
    }

    private class MockServerError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // ─── getApexLogs Tests ────────────────────────────────────────────────────

    @IsTest
    static void testGetApexLogsSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockLogListSuccess());

        Test.startTest();
        DebugLogViewerController.LogListResult result =
            DebugLogViewerController.getApexLogs(null, null, null, 50);
        Test.stopTest();

        Assert.isNull(result.errorMessage, 'Should have no error');
        Assert.areEqual(1, result.totalSize, 'Total size should be 1');
        Assert.areEqual(1, result.records.size(), 'Should return 1 record');
        Assert.areEqual('07L000000000001AAA', result.records[0].id);
        Assert.areEqual('Test User', result.records[0].logUserName);
        Assert.areEqual('Success', result.records[0].status);
    }

    @IsTest
    static void testGetApexLogsWithFilters() {
        Test.setMock(HttpCalloutMock.class, new MockLogListSuccess());

        Test.startTest();
        DebugLogViewerController.LogListResult result =
            DebugLogViewerController.getApexLogs(
                '005000000000001AAA',
                'execute_anonymous',
                'Success',
                10
            );
        Test.stopTest();

        Assert.isNull(result.errorMessage, 'Should have no error with filters');
        Assert.areEqual(1, result.records.size());
    }

    @IsTest
    static void testGetApexLogsLimitCap() {
        Test.setMock(HttpCalloutMock.class, new MockLogListSuccess());

        Test.startTest();
        // Passing 999 — should be silently capped to MAX_LIMIT (200)
        DebugLogViewerController.LogListResult result =
            DebugLogViewerController.getApexLogs(null, null, null, 999);
        Test.stopTest();

        Assert.isNull(result.errorMessage);
    }

    @IsTest
    static void testGetApexLogsApiError() {
        Test.setMock(HttpCalloutMock.class, new MockApiError());

        Test.startTest();
        DebugLogViewerController.LogListResult result =
            DebugLogViewerController.getApexLogs(null, null, null, null);
        Test.stopTest();

        Assert.isNotNull(result.errorMessage, 'Should have an error message');
        Assert.isTrue(result.errorMessage.contains('MALFORMED_QUERY'));
    }

    @IsTest
    static void testGetApexLogsServerError() {
        Test.setMock(HttpCalloutMock.class, new MockServerError());

        Test.startTest();
        DebugLogViewerController.LogListResult result =
            DebugLogViewerController.getApexLogs(null, null, null, null);
        Test.stopTest();

        Assert.isNotNull(result.errorMessage);
    }

    // ─── getLogBody Tests ─────────────────────────────────────────────────────

    @IsTest
    static void testGetLogBodySuccess() {
        Test.setMock(HttpCalloutMock.class, new MockLogBodySuccess());

        Test.startTest();
        DebugLogViewerController.LogBodyResult result =
            DebugLogViewerController.getLogBody('07L000000000001AAA');
        Test.stopTest();

        Assert.isNull(result.errorMessage, 'Should have no error');
        Assert.isTrue(result.body.contains('USER_DEBUG'), 'Body should contain log content');
    }

    @IsTest
    static void testGetLogBodyInvalidId() {
        Test.startTest();
        DebugLogViewerController.LogBodyResult result =
            DebugLogViewerController.getLogBody('INVALID_ID');
        Test.stopTest();

        Assert.isNotNull(result.errorMessage, 'Should return error for invalid Id');
    }

    @IsTest
    static void testGetLogBodyNullId() {
        Test.startTest();
        DebugLogViewerController.LogBodyResult result =
            DebugLogViewerController.getLogBody(null);
        Test.stopTest();

        Assert.isNotNull(result.errorMessage, 'Should return error for null Id');
    }

    @IsTest
    static void testGetLogBodyApiError() {
        Test.setMock(HttpCalloutMock.class, new MockApiError());

        Test.startTest();
        DebugLogViewerController.LogBodyResult result =
            DebugLogViewerController.getLogBody('07L000000000001AAA');
        Test.stopTest();

        Assert.isNotNull(result.errorMessage);
    }

    // ─── deleteApexLogs Tests ─────────────────────────────────────────────────

    @IsTest
    static void testDeleteApexLogsSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockDeleteSuccess());

        Test.startTest();
        DebugLogViewerController.DeleteResult result =
            DebugLogViewerController.deleteApexLogs(
                new List<String>{ '07L000000000001AAA', '07L000000000002AAA' }
            );
        Test.stopTest();

        Assert.isTrue(result.success, 'Delete should succeed');
        Assert.isNull(result.errorMessage);
    }

    @IsTest
    static void testDeleteApexLogsEmptyList() {
        Test.startTest();
        DebugLogViewerController.DeleteResult result =
            DebugLogViewerController.deleteApexLogs(new List<String>());
        Test.stopTest();

        Assert.isTrue(result.success, 'Empty delete list should return success');
    }

    @IsTest
    static void testDeleteApexLogsNullList() {
        Test.startTest();
        DebugLogViewerController.DeleteResult result =
            DebugLogViewerController.deleteApexLogs(null);
        Test.stopTest();

        Assert.isTrue(result.success, 'Null list should return success');
    }

    @IsTest
    static void testDeleteApexLogsInvalidId() {
        Test.startTest();
        DebugLogViewerController.DeleteResult result =
            DebugLogViewerController.deleteApexLogs(
                new List<String>{ 'INVALID_ID' }
            );
        Test.stopTest();

        Assert.isFalse(result.success, 'Invalid Id should fail');
        Assert.isNotNull(result.errorMessage);
    }

    @IsTest
    static void testDeleteApexLogsApiError() {
        Test.setMock(HttpCalloutMock.class, new MockApiError());

        Test.startTest();
        DebugLogViewerController.DeleteResult result =
            DebugLogViewerController.deleteApexLogs(
                new List<String>{ '07L000000000001AAA' }
            );
        Test.stopTest();

        Assert.isFalse(result.success);
        Assert.isNotNull(result.errorMessage);
    }
}
