# Keep the existing API header names and out-of-range behavior on Pagy 43.
Pagy::OPTIONS[:headers_map] = {page: "current-page", limit: "page-items", count: "total-count", pages: "total-pages"}
Pagy::OPTIONS[:raise_range_error] = true
