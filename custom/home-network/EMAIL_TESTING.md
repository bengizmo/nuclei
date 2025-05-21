# Email Notification System Testing

This document describes the testing framework for the email notification system. The test suite aims to achieve a minimum of 90% code coverage and ensure the reliability of the email notification system.

## Test Structure

The test suite consists of:

1. **Unit Tests**: Tests individual functions and components in isolation
2. **Integration Tests**: Tests the interaction between components
3. **End-to-End Deployment Test**: Tests the full deployment process

## Running Tests

You can run the tests using one of the following scripts:

- `run_email_tests.sh`: Runs unit tests with coverage reporting
- `integration_test_email.py`: Runs integration tests 
- `run_all_tests.sh`: Runs all tests and generates a comprehensive report

To run all tests:

```bash
./run_all_tests.sh
```

## Test Files

- `test_email_system.py`: Unit tests for email functionality
- `integration_test_email.py`: Integration tests for the email system
- `run_email_tests.sh`: Script to run unit tests with coverage
- `run_all_tests.sh`: Comprehensive test runner

## Coverage Requirements

The test suite aims to achieve a minimum of 90% code coverage. Coverage is measured using the Python `coverage` package and reported after test execution.

## Unit Tests

The unit test suite tests the following components:

1. **Logging Functions**
   - Verify log messages are written correctly

2. **Email Sending**
   - Test successful email sending
   - Test email with HTML content
   - Test email sending failures

3. **Weekly Summary Generation**
   - Test with no scan data
   - Test with various vulnerability data
   - Test different recommendation scenarios

4. **Critical Vulnerability Detection**
   - Test with no critical vulnerabilities
   - Test with critical vulnerabilities
   - Test alert email generation

5. **Edge Cases**
   - Empty vulnerability files
   - Malformed JSON data
   - Missing scan directories
   - Critical vulnerabilities without names

## Integration Tests

The integration tests validate:

1. **Test Email Functionality**
   - Verify test emails can be sent

2. **Weekly Summary Generation and Delivery**
   - Verify summary content is correct
   - Verify email formatting

3. **Critical Vulnerability Alerts**
   - Verify alerts are triggered when critical vulnerabilities are found
   - Verify no alerts when no critical vulnerabilities are found

4. **Scan Script Integration**
   - Verify the email system is properly triggered from scan scripts

## Deployment Testing

The deployment test validates:

1. **Environment Setup**
   - Verify directories are created correctly
   - Verify permissions are set correctly

2. **Script Installation**
   - Verify scripts are deployed correctly

3. **Email Configuration**
   - Verify email settings are configured correctly

4. **Test Email Delivery**
   - Verify test emails can be sent after deployment

## Adding New Tests

When adding new functionality to the email system, follow these steps:

1. Add unit tests for the new functionality in `test_email_system.py`
2. Add integration tests if the functionality interacts with other components
3. Update the deployment test if needed
4. Ensure code coverage remains at or above 90%

## Continuous Integration

These tests should be run before each deployment to ensure the email notification system functions correctly. The test suite is designed to catch issues with:

- Email delivery
- Vulnerability detection
- Summary generation
- Integration with scanning systems

## Troubleshooting

If tests fail, check:

1. **Log Files**: Check the generated log files for error messages
2. **Coverage Report**: Review the HTML coverage report to identify uncovered code
3. **Test Output**: Check the test output for specific test failures

## Maintaining Tests

As the email system evolves:

1. Keep tests updated to reflect changes in functionality
2. Add new tests for new features
3. Update expected outputs when the format changes
4. Regularly run the full test suite to catch regressions