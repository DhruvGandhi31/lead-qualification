"""Mock Anthropic Messages API for keyless CI and local tests. Standard library only.

NOT a model: it scores leads with a crude keyword heuristic so the pipeline can be exercised
end to end without an API key. Never use its output as evidence of LLM accuracy.

Behaviour switches (put the marker anywhere in the lead message):
  [mock:malformed]       every reply is prose, not JSON      -> pipeline must end in needs_review
  [mock:malformed-once]  first reply is invalid, retry is OK -> proves the single retry works
  [mock:wrong-enum]      replies with score "lukewarm"       -> schema validation must reject it
Auth: a missing or literal "invalid" x-api-key gets a 401, like the real API.
"""
import json
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOT = ("asap", "this week", "urgent", "budget", "approved", "quote", "ready to sign", "book a call",
       "purchase order", "go live", "next week", "by friday", "start immediately")
COLD = ("student", "thesis", "dissertation", "looking for a job", "internship", "unsubscribe",
        "seo services", "guest post", "we offer", "backlink", "just curious", "free sample", "partnership proposal")


def score_message(text: str) -> str:
    t = text.lower()
    if any(k in t for k in COLD):
        return "cold"
    if sum(k in t for k in HOT) >= 2:
        return "hot"
    return "warm"


def build_result(score: str, text: str) -> dict:
    return {
        "score": score,
        "intent": "mock classification of inbound lead",
        "urgency": {"hot": "high", "warm": "medium", "cold": "low"}[score],
        "budget_signal": {"hot": "stated", "warm": "implied", "cold": "none"}[score],
        "summary": f"[mock] Heuristic {score} lead. Message length {len(text)} characters.",
        "suggested_next_step": {"hot": "Call within one hour.", "warm": "Send nurture sequence.",
                                "cold": "Send polite auto-reply."}[score],
    }


def first_user_text(messages: list) -> str:
    for m in messages:
        if m.get("role") == "user":
            c = m.get("content")
            if isinstance(c, str):
                return c
            return "".join(b.get("text", "") for b in c if isinstance(b, dict))
    return ""


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: dict) -> None:
        raw = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):  # health check
        self._send(200, {"ok": True, "mock": True})

    def do_POST(self):
        if self.path.split("?")[0] != "/v1/messages":
            return self._send(404, {"type": "error", "error": {"type": "not_found_error", "message": "no such route"}})
        key = self.headers.get("x-api-key", "")
        if not key or key == "invalid":
            return self._send(401, {"type": "error", "error": {"type": "authentication_error", "message": "invalid x-api-key"}})
        body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
        messages = body.get("messages", [])
        lead_text = first_user_text(messages)
        is_retry = any(m.get("role") == "assistant" for m in messages)

        if "[mock:malformed]" in lead_text or ("[mock:malformed-once]" in lead_text and not is_retry):
            text = "Sure! This looks like a promising lead, I would say it is quite warm."
        elif "[mock:wrong-enum]" in lead_text:
            text = json.dumps({**build_result("warm", lead_text), "score": "lukewarm"})
        else:
            text = json.dumps(build_result(score_message(re.sub(r"\[mock:[a-z-]+\]", "", lead_text)), lead_text))

        self._send(200, {
            "id": "msg_mock", "type": "message", "role": "assistant", "model": body.get("model", "mock"),
            "content": [{"type": "text", "text": text}], "stop_reason": "end_turn", "stop_sequence": None,
            "usage": {"input_tokens": 0, "output_tokens": 0},
        })

    def log_message(self, fmt, *args):
        print("mock-anthropic:", fmt % args, flush=True)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
