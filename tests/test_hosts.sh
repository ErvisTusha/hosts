#!/bin/bash
clear
# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

run_test() {
    local name=$1
    local cmd=$2
    ((TESTS_RUN++))
    
    echo -e "\n${BOLD}Running test:${NC} $name"
    if eval "$cmd"; then
        echo -e "${GREEN}${BOLD}✓ Passed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}${BOLD}✗ Failed${NC}"
        exit 1
    fi
}

# Make script executable
chmod +x hosts.sh
# Pre-clean any test entries that might exist
sudo ./hosts.sh rm test.local >/dev/null 2>&1
sudo ./hosts.sh rm 'test1.local test2.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'multiple.local domains.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'test space.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'domain1.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'domain2.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'test2.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'test3.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'backup.test' >/dev/null 2>&1
sudo ./hosts.sh rm 'addhost.local' >/dev/null 2>&1

# Installation tests
run_test "Install Script" "sudo ./hosts.sh install && command -v hosts"
run_test "Command Aliases" "command -v addhost && command -v rmhost"
run_test "Update Script" "sudo ./hosts.sh update"
run_test "Uninstall Script" "sudo ./hosts.sh uninstall && ! command -v hosts"
run_test "Reinstall After Tests" "sudo ./hosts.sh install && command -v hosts && command -v addhost && command -v rmhost"



# Basic tests
run_test "Banner" "./hosts.sh | grep 'Examples:'"
run_test "Help" "./hosts.sh --help"
run_test "Version" "./hosts.sh --version"
run_test "Invalid Command" "! ./hosts.sh invalid_command"

#remove test entries
sudo ./hosts.sh rm 2001:0db8:85a3:0000:0000:8a2e:0370:7334 >/dev/null 2>&1
sudo ./hosts.sh rm 2001:db8::1 >/dev/null 2>&1
sudo ./hosts.sh rm ::1 >/dev/null 2>&1
sudo ./hosts.sh rm ipv6.localhost.test >/dev/null 2>&1
sudo ./hosts.sh rm mixed.ipv6.test >/dev/null 2>&1

## IPv6 validation tests
run_test "Valid Full IPv6" "sudo ./hosts.sh add 2001:0db8:85a3:0000:0000:8a2e:0370:7334 ipv6.test"
run_test "Valid Compressed IPv6" "sudo ./hosts.sh add 2001:db8::1 compressed.ipv6.test"
run_test "Valid IPv6 Localhost" "sudo ./hosts.sh add ::1 ipv6.localhost.test"
run_test "Invalid IPv6 Format" "! sudo ./hosts.sh add 2001:db8:::1 invalid.ipv6.test"
run_test "Invalid IPv6 Segments" "! sudo ./hosts.sh add 2001:db8:85a3:0000:0000:8a2e:0370:7334:extra invalid.ipv6.test"
run_test "Mixed IPv6 Case" "sudo ./hosts.sh add 2001:DB8::1:CAFE mixed.ipv6.test"

# Add additional test cases after the "Basic tests" section
run_test "Invalid Domain Format" "! sudo ./hosts.sh add 1.1.1.1 'invalid..domain'"
run_test "Domain Too Long" "! sudo ./hosts.sh add 1.1.1.1 $(printf 'a%.0s' {1..256}.com)"
run_test "Domain With Invalid Chars" "! sudo ./hosts.sh add 1.1.1.1 'test@#$.local'"

# Host manipulation tests
run_test "List Hosts" "sudo ./hosts.sh list"
run_test "Add Host" "sudo ./hosts.sh add 1.1.1.1 test.local && grep '1.1.1.1 test.local' /etc/hosts"
run_test "Add Multiple Domains" "sudo ./hosts.sh add 1.1.1.2 'test1.local test2.local' && grep '1.1.1.2 test1.local test2.local' /etc/hosts"
run_test "Add Domains With Spaces" "sudo ./hosts.sh add 1.1.1.3 'multiple.local domains.local' && grep '1.1.1.3 multiple.local domains.local' /etc/hosts"
run_test "Add Host with Spaces" "sudo ./hosts.sh add 1.1.1.4 'test space.local' && grep '1.1.1.4 test space.local' /etc/hosts"
run_test "Remove by IP" "sudo ./hosts.sh rm 1.1.1.3 && ! grep '1.1.1.3' /etc/hosts"
run_test "List Before ID Remove" "sudo ./hosts.sh list"
run_test "Remove by ID" "
    LAST_ID=\$(sudo ./hosts.sh list | tail -n1 | sed -E 's/\x1B\[[0-9;]*[mK]//g' | awk '{print \$1}' | sed 's/\\.\$//') && 
    sudo ./hosts.sh rm \$LAST_ID && 
    ! grep 'test space.local' /etc/hosts
"

# IPv6 host manipulation tests
run_test "List IPv6 Entries" "sudo ./hosts.sh list | grep -i '2001:DB8'"
run_test "Remove IPv6 by Address" "sudo ./hosts.sh rm 2001:db8::1 && ! grep '2001:db8::1' /etc/hosts"
run_test "Remove IPv6 by Domain" "sudo ./hosts.sh rm *ipv6.test && ! grep 'ipv6.test' /etc/hosts"

run_test "Empty IP" "! sudo ./hosts.sh add '' test.local"
run_test "Empty Domain" "! sudo ./hosts.sh add 1.1.1.1 ''"
run_test "AddHost Command" "sudo addhost 5.5.5.5 addhost.local && grep '5.5.5.5 addhost.local' /etc/hosts"
run_test "RmHost Command" "sudo rmhost addhost.local && ! grep 'addhost.local' /etc/hosts"
run_test "Invalid IP" "! sudo ./hosts.sh add 256.256.256.256 invalid.local"

# Add IP validation tests after "Invalid IP" test
run_test "IP With Leading Zeros" "! sudo ./hosts.sh add 001.002.003.004 test.local"
run_test "IP With Spaces" "! sudo ./hosts.sh add '1.1.1.1 ' test.local"
run_test "IP With Letters" "! sudo ./hosts.sh add 1.1.1.abc test.local"

run_test "Duplicate Entry" "! sudo ./hosts.sh add 1.1.1.1 test.local"
run_test "Remove Host" "sudo ./hosts.sh rm test.local && ! grep 'test.local' /etc/hosts"


# Remove 2.2.2.2 and 3.3.3.3 entries
sudo ./hosts.sh rm 2.2.2.2 >/dev/null 2>&1
sudo ./hosts.sh rm 3.3.3.3 >/dev/null 2>&1

# Advanced tests
run_test "Multiple Entries" "
    sudo ./hosts.sh add 2.2.2.2 test2.local && 
    sudo ./hosts.sh add 3.3.3.3 test3.local && 
    grep 'test2.local' /etc/hosts && 
    grep 'test3.local' /etc/hosts
"

# remove  4.4.4.4 entry
sudo ./hosts.sh rm 4.4.4.4 backup.test >/dev/null 2>&1
run_test "Backup Creation" "
    sudo ./hosts.sh add 4.4.4.4 backup.test && 
    ls -l /etc/hosts.*.bak
"

# Add backup tests before "Clean up test entries"
run_test "Backup File Permissions" "
    sudo ./hosts.sh add 4.4.4.4 backup.test
    PERM=$(stat -c %a /etc/hosts.*.bak | tail -1)
    [ \"\$PERM\" = \"644\" ]
"
run_test "Backup Content Match" "
    sudo ./hosts.sh add 5.5.5.5 backup2.test
    LATEST_BACKUP=\$(ls -t /etc/hosts.*.bak | head -1)
    diff /etc/hosts \"\$LATEST_BACKUP\"
    sudo ./hosts.sh rm 5.5.5.5
"

# Search functionality tests
run_test "Search Command Empty" "sudo ./hosts.sh search"
run_test "Search Command Results" "
    sudo ./hosts.sh add 7.7.7.7 search.test && 
    sudo ./hosts.sh search search.test | grep '7.7.7.7' &&
    sudo ./hosts.sh rm search.test
"

# Batch operations tests
run_test "Batch File Missing" "! sudo ./hosts.sh batch nonexistent.txt"
run_test "Batch Add Hosts" "
    echo '8.8.8.8 batch1.test\n9.9.9.9 batch2.test' > test_batch.txt &&
    sudo ./hosts.sh batch test_batch.txt &&
    grep 'batch1.test' /etc/hosts &&
    grep 'batch2.test' /etc/hosts &&
    rm test_batch.txt &&
    sudo ./hosts.sh rm batch1.test &&
    sudo ./hosts.sh rm batch2.test
"

# Additional IPv6 validation tests
run_test "IPv6 Zero Compression" "sudo ./hosts.sh add 2001:db8:0:0:0:0:2:1 ipv6zero.test"
run_test "IPv6 Multiple Zero Compression" "! sudo ./hosts.sh add 2001::db8::1 ipv6invalid.test"
run_test "IPv6 Localhost" "sudo ./hosts.sh add ::1 ipv6local.test"

# Clean up added test entries
sudo ./hosts.sh rm ipv6zero.test >/dev/null 2>&1
sudo ./hosts.sh rm ipv6local.test >/dev/null 2>&1

# Pre-clean any test entries that might exist
sudo ./hosts.sh rm test.local >/dev/null 2>&1
sudo ./hosts.sh rm 'test1.local test2.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'multiple.local domains.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'test space.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'domain1.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'domain2.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'test2.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'test3.local' >/dev/null 2>&1
sudo ./hosts.sh rm 'backup.test' >/dev/null 2>&1
sudo ./hosts.sh rm 'addhost.local' >/dev/null 2>&1
# Clean up test entries
sudo ./hosts.sh rm 5.5.5.5 >/dev/null 2>&1

# Add cleanup for new test entries
sudo ./hosts.sh rm backup2.test >/dev/null 2>&1
sudo ./hosts.sh rm 001.002.003.004 >/dev/null 2>&1

# Clean up IPv6 test entries
sudo ./hosts.sh rm ipv6.test >/dev/null 2>&1
sudo ./hosts.sh rm compressed.ipv6.test >/dev/null 2>&1
sudo ./hosts.sh rm ipv6.localhost.test >/dev/null 2>&1
sudo ./hosts.sh rm mixed.ipv6.test >/dev/null 2>&1


# Clean up backup files
sudo rm -rf /etc/hosts.*.bak


## Improve summary output with color formatting
echo -e "\n${BOLD}Test Summary:${NC}"
echo "Ran $TESTS_RUN tests"
if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}All tests passed!${NC}"
else 
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $((TESTS_RUN - TESTS_PASSED))${NC}"
fi

# Exit with success only if all tests passed
[ $TESTS_PASSED -eq $TESTS_RUN ]