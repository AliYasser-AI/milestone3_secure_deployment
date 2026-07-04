"""
Single shared SlowAPI Limiter instance.

All routers must import `limiter` from here (not create their own) so that
rate-limit state is consistent and the app-level exception handler in
main.py applies uniformly.
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
