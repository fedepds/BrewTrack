from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from starlette.exceptions import HTTPException as StarletteHTTPException


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str):
        self.status, self.code, self.message = status, code, message


def _body(code: str, message: str) -> dict:
    return {"error": {"code": code, "message": message}}


def commit_or_409(db: Session, code: str, message: str) -> None:
    """Commit; una violación de unicidad/FK se traduce a 409."""
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise ApiError(409, code, message)


async def _api(_: Request, e: ApiError) -> JSONResponse:
    return JSONResponse(_body(e.code, e.message), status_code=e.status)


async def _http(_: Request, e: StarletteHTTPException) -> JSONResponse:
    return JSONResponse(_body("http_error", str(e.detail)), status_code=e.status_code)


def _one(x: dict) -> str:
    loc = ".".join(str(p) for p in x["loc"][1:])
    return f"{loc}: {x['msg']}" if loc else x["msg"]


async def _validation(_: Request, e: RequestValidationError) -> JSONResponse:
    return JSONResponse(_body("validation_error", "; ".join(_one(x) for x in e.errors())), status_code=422)


def install(app: FastAPI) -> None:
    app.add_exception_handler(ApiError, _api)
    app.add_exception_handler(StarletteHTTPException, _http)
    app.add_exception_handler(RequestValidationError, _validation)
