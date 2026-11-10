"""SEC-first XBRL evidence prototype (offline-first; not a deployed service)."""
from .core import SECError, build_evidence, normalize_cik, fetch_company_documents

__all__ = ["SECError", "build_evidence", "normalize_cik", "fetch_company_documents"]
