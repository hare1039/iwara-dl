import cloudscraper
import argparse
import sys

def parse_headers(header_list):
    headers = {}
    for h in header_list or []:
        if ':' not in h:
            print(f"Invalid header format: {h}", file=sys.stderr)
            continue
        key, value = h.split(':', 1)
        headers[key.strip()] = value.strip()
    return headers

def main():
    parser = argparse.ArgumentParser(description="Cloudscraper cURL-like wrapper")
    parser.add_argument('url', help='Target URL')
    parser.add_argument('-X', '--request', help='HTTP method to use', default='GET')
    parser.add_argument('-H', '--header', action='append', help='Pass custom header(s) to server')
    parser.add_argument('--data-raw', help='Request body')
    parser.add_argument('--oauth2-bearer', help='OAuth2 Bearer token')
    parser.add_argument('--silent', action='store_true', help='Suppress response output')

    args = parser.parse_args()

    scraper = cloudscraper.create_scraper()
    headers = parse_headers(args.header)

    if args.oauth2_bearer:
        headers['Authorization'] = f'Bearer {args.oauth2_bearer}'

    method = args.request.upper()
    try:
        resp = scraper.request(
            method,
            args.url,
            headers=headers,
            data=args.data_raw if method in ['POST', 'PUT', 'PATCH'] else None
        )
        print(resp.text)
    except Exception as e:
        print(f"[Error] {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
