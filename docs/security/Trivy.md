Salida del escaner de trivy: 
==> Downloading bottle manifests
✔︎ Bottle Manifest ca-certificates (2026-11-05)                          Downloaded    8.1KB/  8.1KB
✔︎ Bottle Manifest harfbuzz (15.1.0)                                     Downloaded  158.2KB/158.2KB
==> Would upgrade 2 outdated packages
harfbuzz         15.0.0_1   -> 15.1.0      (4.4MB)
ca-certificates  2026-10-20 -> 2026-11-05  (109.6KB)
==> Do you want to proceed with the upgrade? [y/n]
==> Fetching downloads for: harfbuzz and ca-certificates
✔︎ Bottle ca-certificates (2026-11-05)                                   Downloaded  109.6KB/109.6KB
✔︎ Bottle harfbuzz (15.1.0)                                              Downloaded    4.4MB/  4.4MB
==> Upgrading harfbuzz
  15.0.0_1 -> 15.1.0
==> Pouring harfbuzz--15.1.0.arm64_golden_gate.bottle.tar.gz
🍺  /opt/homebrew/Cellar/harfbuzz/15.1.0: 96 files, 16.4MB
==> Upgrading ca-certificates
  2026-10-20 -> 2026-11-05
==> Pouring ca-certificates--2026-11-05.all.bottle.tar.gz
🍺  /opt/homebrew/Cellar/ca-certificates/2026-11-05: 5 files, 196.1KB
==> Cleanup
Removing: /opt/homebrew/Cellar/ca-certificates/2026-10-20... (5 files, 196.1KB)
Removing: /opt/homebrew/Cellar/harfbuzz/15.0.0_1... (96 files, 16.3MB)
Disable this behaviour by setting `HOMEBREW_NO_INSTALL_CLEANUP=1`.
Hide these hints with `HOMEBREW_NO_ENV_HINTS=1` (see `man brew`).
==> Upgraded 2 outdated packages
harfbuzz         15.0.0_1   -> 15.1.0
ca-certificates  2026-10-20 -> 2026-11-05
federicopizarro@Mac BrewTrack2 % docker images
                                                                                i Info →   U  In Use
IMAGE                                               ID             DISK USAGE   CONTENT SIZE   EXTRA
gcr.io/k8s-minikube/kicbase:v0.0.51                 84eb673a845f       1.83GB          493MB
gcr.io/k8s-minikube/kicbase@sha256:4a1c825b61479e6c898851ea66f13c620aaeab6002746e95067fc2c4b38a0b24
                                                    4a1c825b6147       1.83GB          493MB    U
ghcr.io/cirruslabs/flutter:stable                   46691e311715       5.97GB         1.94GB
jenkins/jenkins:lts                                 74401de6a6f9        738MB          243MB    U
localhost/brewtrack-api:0.1.0                       46c807f81b4c        348MB         75.1MB    U
localhost/brewtrack-web:0.1.0                       6ab2e59703dc        155MB         42.6MB    U
localhost/brewtrack-web:master                      389ae4724269        151MB         41.2MB
nginx:alpine                                        a3554c0d0b48       94.1MB         27.2MB
postgres:17-alpine                                  266d3c257594        415MB          116MB    U
python:3.13-slim                                    2d44738ebf4c        204MB         45.5MB
federicopizarro@Mac BrewTrack2 % docker compose config --images | while read img; do
  trivy image --severity HIGH,CRITICAL "$img"
done
2026-11-05T17:00:55-03:00	INFO	[vulndb] Need to update DB
2026-11-05T17:00:55-03:00	INFO	[vulndb] Downloading vulnerability DB...
2026-11-05T17:00:55-03:00	INFO	[vulndb] Downloading artifact...	repo="mirror.gcr.io/aquasec/trivy-db:2"
132.37 MiB / 132.37 MiB [-----------------------------------------------] 100.00% 24.30 MiB p/s 5.6s
2026-11-05T17:01:04-03:00	INFO	[vulndb] Artifact successfully downloaded	repo="mirror.gcr.io/aquasec/trivy-db:2"
2026-11-05T17:01:04-03:00	INFO	[vuln] Vulnerability scanning is enabled
2026-11-05T17:01:04-03:00	INFO	[secret] Secret scanning is enabled
2026-11-05T17:01:04-03:00	INFO	[secret] If your scanning is slow, please try '--scanners vuln' to disable secret scanning
2026-11-05T17:01:04-03:00	INFO	[secret] Please see https://trivy.dev/docs/v0.76/guide/scanner/secret#recommendation for faster secret detection
2026-11-05T17:01:04-03:00	INFO	Detected OS	family="alpine" version="3.24.3"
2026-11-05T17:01:04-03:00	INFO	[alpine] Detecting vulnerabilities...	os_version="3.24" repository="3.24" pkg_num=72
2026-11-05T17:01:04-03:00	INFO	Number of language-specific files	num=0
2026-11-05T17:01:04-03:00	WARN	Using severities from other vendors for some vulnerabilities. Read https://trivy.dev/docs/v0.76/guide/scanner/vulnerability#severity-selection for details.

Report Summary

┌───────────────────────────────────────────────┬────────┬─────────────────┬─────────┐
│                    Target                     │  Type  │ Vulnerabilities │ Secrets │
├───────────────────────────────────────────────┼────────┼─────────────────┼─────────┤
│ localhost/brewtrack-web:0.1.0 (alpine 3.24.3) │ alpine │        6        │    -    │
└───────────────────────────────────────────────┴────────┴─────────────────┴─────────┘
Legend:
- '-': Not scanned
- '0': Clean (no security findings detected)


localhost/brewtrack-web:0.1.0 (alpine 3.24.3)

Total: 6 (HIGH: 5, CRITICAL: 1)

┌─────────────┬─────────────────┬──────────┬────────┬───────────────────┬───────────────┬──────────────────────────────────────────────────────────────┐
│   Library   │  Vulnerability  │ Severity │ Status │ Installed Version │ Fixed Version │                            Title                             │
├─────────────┼─────────────────┼──────────┼────────┼───────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ brotli-libs │ CVE-2026-111497 │ CRITICAL │ fixed  │ 1.2.0-r1          │ 1.2.1-r0      │ brotli: Out-of-Bounds Write in Google Brotli Decoder         │
│             │                 │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2026-111497                  │
├─────────────┼─────────────────┼──────────┤        ├───────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ curl        │ CVE-2026-92392  │ HIGH     │        │ 8.22.0-r0         │ 8.23.0-r0     │ curl: curl: HTTP/2 upload Use-After-Free                     │
│             │                 │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2026-92392                   │
├─────────────┤                 │          │        │                   │               │                                                              │
│ libcurl     │                 │          │        │                   │               │                                                              │
│             │                 │          │        │                   │               │                                                              │
├─────────────┼─────────────────┤          │        ├───────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ libexpat    │ CVE-2026-113351 │          │        │ 2.9.0-r0          │ 2.10.0-r0     │ expat: expat: Denial of Service via improper memory tracking │
│             │                 │          │        │                   │               │ in XML_ParserReset                                           │
│             │                 │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2026-113351                  │
│             ├─────────────────┤          │        │                   │               ├──────────────────────────────────────────────────────────────┤
│             │ CVE-2026-117610 │          │        │                   │               │ expat: expat: Denial of Service via NULL pointer dereference │
│             │                 │          │        │                   │               │ in external entity...                                        │
│             │                 │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2026-117610                  │
│             ├─────────────────┤          │        │                   │               ├──────────────────────────────────────────────────────────────┤
│             │ CVE-2026-118370 │          │        │                   │               │ expat: expat: Denial of Service via integer overflow during  │
│             │                 │          │        │                   │               │ XML attribute parsing...                                     │
│             │                 │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2026-118370                  │
└─────────────┴─────────────────┴──────────┴────────┴───────────────────┴───────────────┴──────────────────────────────────────────────────────────────┘

📣 Notices:
  - Version 0.76.2 of Trivy is now available, current version is 0.76.1

To suppress version checks, run Trivy scans with the --skip-version-check flag

2026-11-05T17:01:04-03:00	INFO	[vuln] Vulnerability scanning is enabled
2026-11-05T17:01:04-03:00	INFO	[secret] Secret scanning is enabled
2026-11-05T17:01:04-03:00	INFO	[secret] If your scanning is slow, please try '--scanners vuln' to disable secret scanning
2026-11-05T17:01:04-03:00	INFO	[secret] Please see https://trivy.dev/docs/v0.76/guide/scanner/secret#recommendation for faster secret detection
2026-11-05T17:01:06-03:00	INFO	Detected OS	family="alpine" version="3.24.3"
2026-11-05T17:01:06-03:00	INFO	[alpine] Detecting vulnerabilities...	os_version="3.24" repository="3.24" pkg_num=45
2026-11-05T17:01:06-03:00	INFO	Number of language-specific files	num=1
2026-11-05T17:01:06-03:00	INFO	[gobinary] Detecting vulnerabilities...
2026-11-05T17:01:06-03:00	WARN	Using severities from other vendors for some vulnerabilities. Read https://trivy.dev/docs/v0.76/guide/scanner/vulnerability#severity-selection for details.

Report Summary

┌──────────────────────────────────────────────────────┬──────────┬─────────────────┬─────────┐
│                        Target                        │   Type   │ Vulnerabilities │ Secrets │
├──────────────────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ docker.io/library/postgres:17-alpine (alpine 3.24.3) │  alpine  │        0        │    -    │
├──────────────────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ usr/local/bin/gosu                                   │ gobinary │       26        │    -    │
└──────────────────────────────────────────────────────┴──────────┴─────────────────┴─────────┘
Legend:
- '-': Not scanned
- '0': Clean (no security findings detected)


usr/local/bin/gosu (gobinary)

Total: 26 (HIGH: 25, CRITICAL: 1)

┌─────────┬─────────────────┬──────────┬────────┬───────────────────┬──────────────────────────────┬──────────────────────────────────────────────────────────────┐
│ Library │  Vulnerability  │ Severity │ Status │ Installed Version │        Fixed Version         │                            Title                             │
├─────────┼─────────────────┼──────────┼────────┼───────────────────┼──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│ stdlib  │ CVE-2025-68121  │ CRITICAL │ fixed  │ v1.24.6           │ 1.24.13, 1.25.7, 1.26.0-rc.3 │ crypto/tls: crypto/tls: Incorrect certificate validation     │
│         │                 │          │        │                   │                              │ during TLS session resumption                                │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2025-68121                   │
│         ├─────────────────┼──────────┤        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2025-61726  │ HIGH     │        │                   │ 1.24.12, 1.25.6              │ golang: net/url: Memory exhaustion in query parameter        │
│         │                 │          │        │                   │                              │ parsing in net/url                                           │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2025-61726                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2025-61729  │          │        │                   │ 1.24.11, 1.25.5              │ crypto/x509: golang: Denial of Service due to excessive      │
│         │                 │          │        │                   │                              │ resource consumption via crafted...                          │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2025-61729                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-111943 │          │        │                   │ 1.26.10, 1.27.3              │ crypto/x509: golang: crypto/x509: Man-in-the-middle attacks  │
│         │                 │          │        │                   │                              │ via untrusted intermediate certificates                      │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-111943                  │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-25679  │          │        │                   │ 1.25.8, 1.26.1               │ net/url: Incorrect parsing of IPv6 host literals in net/url  │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-25679                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-27145  │          │        │                   │ 1.25.11, 1.26.4              │ crypto/x509: golang: golang crypto/x509: Denial of Service   │
│         │                 │          │        │                   │                              │ via excessive processing of DNS...                           │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-27145                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-32280  │          │        │                   │ 1.25.9, 1.26.2               │ crypto/x509: crypto/tls: golang: Go: Denial of Service       │
│         │                 │          │        │                   │                              │ vulnerability in certificate chain building...               │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-32280                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-32281  │          │        │                   │                              │ crypto/x509: golang: Go crypto/x509: Denial of Service via   │
│         │                 │          │        │                   │                              │ inefficient certificate chain validation...                  │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-32281                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-32283  │          │        │                   │                              │ crypto/tls: golang: Go crypto/tls: Denial of Service via     │
│         │                 │          │        │                   │                              │ multiple TLS 1.3 key...                                      │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-32283                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-33811  │          │        │                   │ 1.25.10, 1.26.3              │ net: golang: Go net package: Denial of Service via long      │
│         │                 │          │        │                   │                              │ CNAME response...                                            │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-33811                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-33814  │          │        │                   │                              │ net/http/internal/http2: golang: golang.org/x/net: Go        │
│         │                 │          │        │                   │                              │ HTTP/2: Denial of Service via malformed                      │
│         │                 │          │        │                   │                              │ SETTINGS_MAX_FRAME_SIZE frame...                             │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-33814                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-33818  │          │        │                   │ 1.25.13, 1.26.6, 1.27.0-rc.3 │ encoding/asn1: golang: Go encoding/asn1: Denial of Service   │
│         │                 │          │        │                   │                              │ via excessive recursion in Unmarshal...                      │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-33818                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-39820  │          │        │                   │ 1.25.10, 1.26.3              │ net/mail: golang: Go net/mail: Denial of Service via crafted │
│         │                 │          │        │                   │                              │ email inputs                                                 │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-39820                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-39821  │          │        │                   │ 1.25.13, 1.26.6, 1.27.0-rc.3 │ golang.org/x/net/idna: golang: net/http:                     │
│         │                 │          │        │                   │                              │ golang.org/x/net/idna: Privilege escalation via incorrect    │
│         │                 │          │        │                   │                              │ Punycode label processing                                    │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-39821                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-39822  │          │        │                   │ 1.25.12, 1.26.5, 1.27.0-rc.2 │ golang: Go os.Root: Symlink following vulnerability allows   │
│         │                 │          │        │                   │                              │ directory traversal                                          │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-39822                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-39836  │          │        │                   │ 1.25.10, 1.26.3              │ net: golang: Go net package: Denial of Service via NUL byte  │
│         │                 │          │        │                   │                              │ in...                                                        │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-39836                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-42499  │          │        │                   │                              │ net/mail: golang: net/mail: Denial of Service via            │
│         │                 │          │        │                   │                              │ pathological email address parsing                           │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-42499                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-42504  │          │        │                   │ 1.25.11, 1.26.4              │ mime: golang: Golang MIME: Denial of Service via             │
│         │                 │          │        │                   │                              │ maliciously-crafted MIME header                              │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-42504                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-56853  │          │        │                   │ 1.25.13, 1.26.6, 1.27.0-rc.3 │ net/http: golang: Go net/http: Unencrypted HTTP/2            │
│         │                 │          │        │                   │                              │ connections vulnerable to Denial of Service...               │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-56853                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-56858  │          │        │                   │                              │ html/template: golang: Go html/template: Cross-Site          │
│         │                 │          │        │                   │                              │ Scripting via pathological input                             │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-56858                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-56859  │          │        │                   │                              │ encoding/xml: golang: Go: Denial of Service via XML decoding │
│         │                 │          │        │                   │                              │ recursion depth issue...                                     │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-56859                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-56860  │          │        │                   │                              │ net/url: golang: golang net/url: Denial of Service from      │
│         │                 │          │        │                   │                              │ quadratic complexity in path...                              │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-56860                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-56862  │          │        │                   │                              │ crypto/tls: golang: Golang crypto/tls: Denial of Service via │
│         │                 │          │        │                   │                              │ indefinite KeyUpdate messages                                │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-56862                   │
│         ├─────────────────┤          │        │                   ├──────────────────────────────┼──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-78667  │          │        │                   │ 1.26.9, 1.27.2               │ net/http: golang: golang: Denial of Service via crafted HTTP │
│         │                 │          │        │                   │                              │ Range headers                                                │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-78667                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-78669  │          │        │                   │                              │ net/http: net/http/internal/http2: golang.org/x/net/http2:   │
│         │                 │          │        │                   │                              │ net/http: Denial of Service via excessive HTTP/2 SETTINGS    │
│         │                 │          │        │                   │                              │ frames...                                                    │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-78669                   │
│         ├─────────────────┤          │        │                   │                              ├──────────────────────────────────────────────────────────────┤
│         │ CVE-2026-97031  │          │        │                   │                              │ crypto/tls: golang: crypto/tls: Denial of Service via        │
│         │                 │          │        │                   │                              │ multiple ECH outer extension references...                   │
│         │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-97031                   │
└─────────┴─────────────────┴──────────┴────────┴───────────────────┴──────────────────────────────┴──────────────────────────────────────────────────────────────┘

📣 Notices:
  - Version 0.76.2 of Trivy is now available, current version is 0.76.1

To suppress version checks, run Trivy scans with the --skip-version-check flag

2026-11-05T17:01:06-03:00	INFO	[vuln] Vulnerability scanning is enabled
2026-11-05T17:01:06-03:00	INFO	[secret] Secret scanning is enabled
2026-11-05T17:01:06-03:00	INFO	[secret] If your scanning is slow, please try '--scanners vuln' to disable secret scanning
2026-11-05T17:01:06-03:00	INFO	[secret] Please see https://trivy.dev/docs/v0.76/guide/scanner/secret#recommendation for faster secret detection
2026-11-05T17:01:07-03:00	WARN	Third-party SBOM may lead to inaccurate vulnerability detection
2026-11-05T17:01:07-03:00	WARN	Recommend using Trivy to generate SBOMs
2026-11-05T17:01:07-03:00	INFO	[python] Licenses acquired from one or more METADATA files may be subject to additional terms. Use `--debug` flag to see all affected packages.
2026-11-05T17:01:07-03:00	INFO	Detected OS	family="debian" version="13.7"
2026-11-05T17:01:07-03:00	INFO	[debian] Detecting vulnerabilities...	os_version="13" pkg_num=87
2026-11-05T17:01:07-03:00	INFO	Number of language-specific files	num=1
2026-11-05T17:01:07-03:00	INFO	[python-pkg] Detecting vulnerabilities...
2026-11-05T17:01:07-03:00	WARN	Using severities from other vendors for some vulnerabilities. Read https://trivy.dev/docs/v0.76/guide/scanner/vulnerability#severity-selection for details.

Report Summary

┌──────────────────────────────────────────────────────────────────────────────────┬────────────┬─────────────────┬─────────┐
│                                      Target                                      │    Type    │ Vulnerabilities │ Secrets │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ localhost/brewtrack-api:0.1.0 (debian 13.7)                                      │   debian   │       48        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ Python                                                                           │ python-pkg │        5        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/alembic-1.20.1.dist-info/METADATA         │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/annotated_doc-0.0.5.dist-info/METADATA    │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/annotated_types-0.8.0.dist-info/METADATA  │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/anyio-4.16.0.dist-info/METADATA           │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/argon2_cffi-25.1.0.dist-info/METADATA     │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/argon2_cffi_bindings-26.1.0.dist-info/ME- │ python-pkg │        0        │    -    │
│ TADATA                                                                           │            │                 │         │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/brewtrack_api-0.1.0.dist-info/METADATA    │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/cffi-2.1.1.dist-info/METADATA             │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/click-8.5.0.dist-info/METADATA            │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/dnspython-2.9.1.dist-info/METADATA        │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/email_validator-2.3.0.dist-info/METADATA  │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/fastapi-0.162.0.dist-info/METADATA        │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/h11-0.16.0.dist-info/METADATA             │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/httptools-0.9.0.dist-info/METADATA        │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/idna-3.20.dist-info/METADATA              │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/mako-1.4.3.dist-info/METADATA             │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/markupsafe-3.0.4.dist-info/METADATA       │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/opentelemetry_api-1.45.2.dist-info/METAD- │ python-pkg │        0        │    -    │
│ ATA                                                                              │            │                 │         │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/pip-26.2.2.dist-info/METADATA             │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/prometheus_client-0.26.0.dist-info/METAD- │ python-pkg │        0        │    -    │
│ ATA                                                                              │            │                 │         │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/prometheus_fastapi_instrumentator-8.1.0.- │ python-pkg │        0        │    -    │
│ dist-info/METADATA                                                               │            │                 │         │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/psycopg-3.3.7.dist-info/METADATA          │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/psycopg_binary-3.3.7.dist-info/METADATA   │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/pycparser-3.12.dist-info/METADATA         │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/pydantic-2.14.2.dist-info/METADATA        │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/pydantic_core-2.50.2.dist-info/METADATA   │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/pydantic_settings-2.16.2.dist-info/METAD- │ python-pkg │        0        │    -    │
│ ATA                                                                              │            │                 │         │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/pyjwt-2.15.1.dist-info/METADATA           │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/python_dotenv-1.2.4.dist-info/METADATA    │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/pyyaml-6.0.3.dist-info/METADATA           │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/sqlalchemy-2.1.7.dist-info/METADATA       │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/starlette-1.10.0.dist-info/METADATA       │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/typing_extensions-4.16.0.dist-info/METAD- │ python-pkg │        0        │    -    │
│ ATA                                                                              │            │                 │         │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/typing_inspection-0.4.4.dist-info/METADA- │ python-pkg │        0        │    -    │
│ TA                                                                               │            │                 │         │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/uvicorn-0.54.0.dist-info/METADATA         │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/uvloop-0.23.0.dist-info/METADATA          │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/watchfiles-1.3.0.dist-info/METADATA       │ python-pkg │        0        │    -    │
├──────────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┼─────────┤
│ usr/local/lib/python3.13/site-packages/websockets-17.4.dist-info/METADATA        │ python-pkg │        0        │    -    │
└──────────────────────────────────────────────────────────────────────────────────┴────────────┴─────────────────┴─────────┘
Legend:
- '-': Not scanned
- '0': Clean (no security findings detected)


localhost/brewtrack-api:0.1.0 (debian 13.7)

Total: 48 (HIGH: 48, CRITICAL: 0)

┌───────────────┬─────────────────┬──────────┬──────────────┬───────────────────────────────────┬───────────────┬─────────────────────────────────────────────────────────────┐
│    Library    │  Vulnerability  │ Severity │    Status    │         Installed Version         │ Fixed Version │                            Title                            │
├───────────────┼─────────────────┼──────────┼──────────────┼───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ apt           │ CVE-2026-109518 │ HIGH     │ fixed        │ 3.0.3                             │ 3.0.4         │ On Debian, Ubuntu, and derivative Linux distributions, an   │
│               │                 │          │              │                                   │               │ on-path atta ...                                            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-109518                 │
├───────────────┼─────────────────┤          ├──────────────┼───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ bsdutils      │ CVE-2026-76642  │          │ affected     │ 1:2.41.5-0+deb13u1                │               │ util-linux: util-linux: failed external mount helper still  │
│               │                 │          │              │                                   │               │ runs privileged X-mount post-hooks                          │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76642                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78408  │          │              │                                   │               │ util-linux: util-linux: nsenter --join-cgroup leaks root    │
│               │                 │          │              │                                   │               │ cgroup migration authority                                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78408                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78409  │          │              │                                   │               │ util-linux: util-linux: X-mount.subdir detached-tree        │
│               │                 │          │              │                                   │               │ resolution can escape via intermediate symlinks             │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78409                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78410  │          │              │                                   │               │ util-linux: util-linux: restricted bind mounts do not pin   │
│               │                 │          │              │                                   │               │ the source, allowing X-mount.owner/group/mode...            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78410                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libacl1       │ CVE-2026-54369  │          │              │ 2.3.2-2+b1                        │               │ acl: Symlink traversal privilege escalation via libacl      │
│               │                 │          │              │                                   │               │ functions                                                   │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-54369                  │
├───────────────┼─────────────────┤          ├──────────────┼───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libapt-pkg7.0 │ CVE-2026-109518 │          │ fixed        │ 3.0.3                             │ 3.0.4         │ On Debian, Ubuntu, and derivative Linux distributions, an   │
│               │                 │          │              │                                   │               │ on-path atta ...                                            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-109518                 │
├───────────────┼─────────────────┤          ├──────────────┼───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libblkid1     │ CVE-2026-76642  │          │ affected     │ 2.41.5-0+deb13u1                  │               │ util-linux: util-linux: failed external mount helper still  │
│               │                 │          │              │                                   │               │ runs privileged X-mount post-hooks                          │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76642                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78408  │          │              │                                   │               │ util-linux: util-linux: nsenter --join-cgroup leaks root    │
│               │                 │          │              │                                   │               │ cgroup migration authority                                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78408                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78409  │          │              │                                   │               │ util-linux: util-linux: X-mount.subdir detached-tree        │
│               │                 │          │              │                                   │               │ resolution can escape via intermediate symlinks             │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78409                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78410  │          │              │                                   │               │ util-linux: util-linux: restricted bind mounts do not pin   │
│               │                 │          │              │                                   │               │ the source, allowing X-mount.owner/group/mode...            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78410                  │
├───────────────┼─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│ liblastlog2-2 │ CVE-2026-76642  │          │              │                                   │               │ util-linux: util-linux: failed external mount helper still  │
│               │                 │          │              │                                   │               │ runs privileged X-mount post-hooks                          │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76642                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78408  │          │              │                                   │               │ util-linux: util-linux: nsenter --join-cgroup leaks root    │
│               │                 │          │              │                                   │               │ cgroup migration authority                                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78408                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78409  │          │              │                                   │               │ util-linux: util-linux: X-mount.subdir detached-tree        │
│               │                 │          │              │                                   │               │ resolution can escape via intermediate symlinks             │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78409                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78410  │          │              │                                   │               │ util-linux: util-linux: restricted bind mounts do not pin   │
│               │                 │          │              │                                   │               │ the source, allowing X-mount.owner/group/mode...            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78410                  │
├───────────────┼─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│ libmount1     │ CVE-2026-76642  │          │              │                                   │               │ util-linux: util-linux: failed external mount helper still  │
│               │                 │          │              │                                   │               │ runs privileged X-mount post-hooks                          │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76642                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78408  │          │              │                                   │               │ util-linux: util-linux: nsenter --join-cgroup leaks root    │
│               │                 │          │              │                                   │               │ cgroup migration authority                                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78408                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78409  │          │              │                                   │               │ util-linux: util-linux: X-mount.subdir detached-tree        │
│               │                 │          │              │                                   │               │ resolution can escape via intermediate symlinks             │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78409                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78410  │          │              │                                   │               │ util-linux: util-linux: restricted bind mounts do not pin   │
│               │                 │          │              │                                   │               │ the source, allowing X-mount.owner/group/mode...            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78410                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libncursesw6  │ CVE-2025-69720  │          │              │ 6.5+20250216-2                    │               │ ncurses: ncurses: Buffer overflow vulnerability may lead to │
│               │                 │          │              │                                   │               │ arbitrary code execution.                                   │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2025-69720                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libsmartcols1 │ CVE-2026-76642  │          │              │ 2.41.5-0+deb13u1                  │               │ util-linux: util-linux: failed external mount helper still  │
│               │                 │          │              │                                   │               │ runs privileged X-mount post-hooks                          │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76642                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78408  │          │              │                                   │               │ util-linux: util-linux: nsenter --join-cgroup leaks root    │
│               │                 │          │              │                                   │               │ cgroup migration authority                                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78408                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78409  │          │              │                                   │               │ util-linux: util-linux: X-mount.subdir detached-tree        │
│               │                 │          │              │                                   │               │ resolution can escape via intermediate symlinks             │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78409                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78410  │          │              │                                   │               │ util-linux: util-linux: restricted bind mounts do not pin   │
│               │                 │          │              │                                   │               │ the source, allowing X-mount.owner/group/mode...            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78410                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libsqlite3-0  │ CVE-2026-119373 │          │              │ 3.46.1-7+deb13u2                  │               │ sqlite: sqlite: Denial of service via heap-based buffer     │
│               │                 │          │              │                                   │               │ overflow in FTS5                                            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-119373                 │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libsystemd0   │ CVE-2026-16742  │          │              │ 257.13-1~deb13u1                  │               │ systemd: systemd-homed: Local privilege escalation via      │
│               │                 │          │              │                                   │               │ missing home-record signature verification                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-16742                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libtinfo6     │ CVE-2025-69720  │          │              │ 6.5+20250216-2                    │               │ ncurses: ncurses: Buffer overflow vulnerability may lead to │
│               │                 │          │              │                                   │               │ arbitrary code execution.                                   │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2025-69720                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libudev1      │ CVE-2026-16742  │          │              │ 257.13-1~deb13u1                  │               │ systemd: systemd-homed: Local privilege escalation via      │
│               │                 │          │              │                                   │               │ missing home-record signature verification                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-16742                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ libuuid1      │ CVE-2026-76642  │          │              │ 2.41.5-0+deb13u1                  │               │ util-linux: util-linux: failed external mount helper still  │
│               │                 │          │              │                                   │               │ runs privileged X-mount post-hooks                          │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76642                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78408  │          │              │                                   │               │ util-linux: util-linux: nsenter --join-cgroup leaks root    │
│               │                 │          │              │                                   │               │ cgroup migration authority                                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78408                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78409  │          │              │                                   │               │ util-linux: util-linux: X-mount.subdir detached-tree        │
│               │                 │          │              │                                   │               │ resolution can escape via intermediate symlinks             │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78409                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78410  │          │              │                                   │               │ util-linux: util-linux: restricted bind mounts do not pin   │
│               │                 │          │              │                                   │               │ the source, allowing X-mount.owner/group/mode...            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78410                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ login         │ CVE-2026-76642  │          │              │ 1:4.16.0-2+really2.41.5-0+deb13u1 │               │ util-linux: util-linux: failed external mount helper still  │
│               │                 │          │              │                                   │               │ runs privileged X-mount post-hooks                          │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76642                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78408  │          │              │                                   │               │ util-linux: util-linux: nsenter --join-cgroup leaks root    │
│               │                 │          │              │                                   │               │ cgroup migration authority                                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78408                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78409  │          │              │                                   │               │ util-linux: util-linux: X-mount.subdir detached-tree        │
│               │                 │          │              │                                   │               │ resolution can escape via intermediate symlinks             │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78409                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78410  │          │              │                                   │               │ util-linux: util-linux: restricted bind mounts do not pin   │
│               │                 │          │              │                                   │               │ the source, allowing X-mount.owner/group/mode...            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78410                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ mount         │ CVE-2026-76642  │          │              │ 2.41.5-0+deb13u1                  │               │ util-linux: util-linux: failed external mount helper still  │
│               │                 │          │              │                                   │               │ runs privileged X-mount post-hooks                          │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76642                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78408  │          │              │                                   │               │ util-linux: util-linux: nsenter --join-cgroup leaks root    │
│               │                 │          │              │                                   │               │ cgroup migration authority                                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78408                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78409  │          │              │                                   │               │ util-linux: util-linux: X-mount.subdir detached-tree        │
│               │                 │          │              │                                   │               │ resolution can escape via intermediate symlinks             │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78409                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78410  │          │              │                                   │               │ util-linux: util-linux: restricted bind mounts do not pin   │
│               │                 │          │              │                                   │               │ the source, allowing X-mount.owner/group/mode...            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78410                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ ncurses-base  │ CVE-2025-69720  │          │              │ 6.5+20250216-2                    │               │ ncurses: ncurses: Buffer overflow vulnerability may lead to │
│               │                 │          │              │                                   │               │ arbitrary code execution.                                   │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2025-69720                  │
├───────────────┤                 │          │              │                                   ├───────────────┤                                                             │
│ ncurses-bin   │                 │          │              │                                   │               │                                                             │
│               │                 │          │              │                                   │               │                                                             │
│               │                 │          │              │                                   │               │                                                             │
├───────────────┼─────────────────┤          ├──────────────┼───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ perl-base     │ CVE-2026-9538   │          │ fix_deferred │ 5.40.1-6+deb13u1                  │               │ perl-Archive-Tar: perl-Archive-Tar: Denial of Service via   │
│               │                 │          │              │                                   │               │ crafted tar header with large entry...                      │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-9538                   │
├───────────────┼─────────────────┤          ├──────────────┼───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ util-linux    │ CVE-2026-76642  │          │ affected     │ 2.41.5-0+deb13u1                  │               │ util-linux: util-linux: failed external mount helper still  │
│               │                 │          │              │                                   │               │ runs privileged X-mount post-hooks                          │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76642                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78408  │          │              │                                   │               │ util-linux: util-linux: nsenter --join-cgroup leaks root    │
│               │                 │          │              │                                   │               │ cgroup migration authority                                  │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78408                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78409  │          │              │                                   │               │ util-linux: util-linux: X-mount.subdir detached-tree        │
│               │                 │          │              │                                   │               │ resolution can escape via intermediate symlinks             │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78409                  │
│               ├─────────────────┤          │              │                                   ├───────────────┼─────────────────────────────────────────────────────────────┤
│               │ CVE-2026-78410  │          │              │                                   │               │ util-linux: util-linux: restricted bind mounts do not pin   │
│               │                 │          │              │                                   │               │ the source, allowing X-mount.owner/group/mode...            │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-78410                  │
├───────────────┼─────────────────┤          │              ├───────────────────────────────────┼───────────────┼─────────────────────────────────────────────────────────────┤
│ zlib1g        │ CVE-2026-76844  │          │              │ 1:1.3.dfsg+really1.3.1-1+b1       │               │ webpack-dev-middleware: webpack-dev-middleware: Information │
│               │                 │          │              │                                   │               │ Disclosure via Path Traversal                               │
│               │                 │          │              │                                   │               │ https://avd.aquasec.com/nvd/cve-2026-76844                  │
└───────────────┴─────────────────┴──────────┴──────────────┴───────────────────────────────────┴───────────────┴─────────────────────────────────────────────────────────────┘

Python (python-pkg)

Total: 5 (HIGH: 5, CRITICAL: 0)

┌────────────┬─────────────────────┬──────────┬────────┬───────────────────┬───────────────┬────────────────────────────────────────────────────────────┐
│  Library   │    Vulnerability    │ Severity │ Status │ Installed Version │ Fixed Version │                           Title                            │
├────────────┼─────────────────────┼──────────┼────────┼───────────────────┼───────────────┼────────────────────────────────────────────────────────────┤
│ msgpack    │ CVE-2026-114613     │ HIGH     │ fixed  │ 1.1.2             │ 1.2.3         │ msgpack: msgpack: Denial of Service via memory leak during │
│            │                     │          │        │                   │               │ map deserialization                                        │
│            │                     │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2026-114613                │
│            ├─────────────────────┤          │        │                   ├───────────────┼────────────────────────────────────────────────────────────┤
│            │ GHSA-6v7p-g79w-8964 │          │        │                   │ 1.2.1         │ MessagePack for Python: Out-of-bounds read / crash on      │
│            │                     │          │        │                   │               │ Unpacker reuse after a...                                  │
│            │                     │          │        │                   │               │ https://github.com/advisories/GHSA-6v7p-g79w-8964          │
├────────────┼─────────────────────┤          │        ├───────────────────┼───────────────┼────────────────────────────────────────────────────────────┤
│ setuptools │ CVE-2025-47273      │          │        │ 70.3.0            │ 78.1.1        │ setuptools: Path Traversal Vulnerability in setuptools     │
│            │                     │          │        │                   │               │ PackageIndex                                               │
│            │                     │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2025-47273                 │
├────────────┼─────────────────────┤          │        ├───────────────────┼───────────────┼────────────────────────────────────────────────────────────┤
│ urllib3    │ CVE-2026-97687      │          │        │ 2.7.0             │ 2.8.0         │ urllib3: urllib3: Traffic interception via HTTPS proxy TLS │
│            │                     │          │        │                   │               │ configuration override                                     │
│            │                     │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2026-97687                 │
│            ├─────────────────────┤          │        │                   │               ├────────────────────────────────────────────────────────────┤
│            │ CVE-2026-97689      │          │        │                   │               │ urllib3: urllib3: Denial of Service via unbounded memory   │
│            │                     │          │        │                   │               │ allocation in chunk parser...                              │
│            │                     │          │        │                   │               │ https://avd.aquasec.com/nvd/cve-2026-97689                 │
└────────────┴─────────────────────┴──────────┴────────┴───────────────────┴───────────────┴────────────────────────────────────────────────────────────┘

📣 Notices:
  - Version 0.76.2 of Trivy is now available, current version is 0.76.1

To suppress version checks, run Trivy scans with the --skip-version-check flag

federicopizarro@Mac BrewTrack2 %