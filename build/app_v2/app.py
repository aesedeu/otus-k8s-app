from fastapi import FastAPI, Request
from fastapi import FastAPI, status, Response, Request, HTTPException
from pydantic import BaseModel
import uvicorn
import datetime
import pickle

api_version = "0.1.0"
app = FastAPI(
    title="Heart risk API",
    description="API for the first ML model",
    version=api_version
)

@app.on_event("startup") # deprecated
async def load_model():
    global model
    model = pickle.load(open("model_lr.pkl", "rb"))

    global model_name
    model_name = "LogisticRegression"

class model_data(BaseModel):
    Age: int
    Sex: int
    BloodPressure: int
    MaxHeartRate: int

@app.get('/startup', tags=["monitoring_handlers"], description="Ручка для k8s. Проверка запуска пода.")
def startup() -> Response:
    return Response(status_code=status.HTTP_200_OK)

@app.get('/ready', tags=["monitoring_handlers"], description="Ручка для k8s. Проверка готовности пода.")
def startup() -> Response:
    return Response(status_code=status.HTTP_200_OK)

@app.get('/health', tags=["monitoring_handlers"], description="Ручка для k8s. Проверка статуса пода.")
def startup() -> Response:
    return Response(status_code=status.HTTP_200_OK)


@app.get('/')
def read_root():
    return {"model_verison": api_version}

@app.post('/rec', tags=["prediction"])
async def get_heart_risk(data: model_data):
    result = model.predict([[data.Age, data.Sex, data.BloodPressure, data.MaxHeartRate]])[0]
    if result == 0:
        result = 'Вы вне группы сердечного риска'
    else:
        result = 'Вы в группе риска, обратитесь к врачу!'
    json_response = {
        "timestamp": datetime.datetime.now().timestamp(),
        "model_name": model_name,
        "model_response": result
    }
    return json_response


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=80)