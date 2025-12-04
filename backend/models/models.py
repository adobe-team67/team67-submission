from pydantic import BaseModel
from typing import List, Dict, Optional


class SelectionPoint(BaseModel):
    x: float
    y: float


class SetSelectionRequest(BaseModel):
    image: str                    
    bitmask: List[List[int]]      
    continuation: bool = False  
    label: Optional[str] = None   
    x: Optional[int] = None       
    y: Optional[int] = None      


class RefineSelectionRequest(BaseModel):
    image: str  # base64 encoded image
    imageWidth: int
    imageHeight: int
    selectionPoint: Optional[Dict[str, float]] = None


class RefineSelectionResponse(BaseModel):
    bitmask: List[List[int]]
    width: int
    height: int
    message: str


class EraseRequest(BaseModel):
    image_name: str
    masks_ids: List[int]
    manual_masks: Optional[List[List[List[int]]]] = None

class Metric(BaseModel):
    timestamp: int  
    cpu: float      
    gpu: float      
    memory: float   

class EraseResponse(BaseModel):
    image: str
    message: str

class img2imgResponse(BaseModel):
    image: str
    message: str
    metrics: List[Metric]

class MoveRequest(BaseModel):
    image_name: str
    masks_ids: List[int]
    endx: int
    endy: int
    startx: int
    starty: int
    prompt: Optional[str] = None
    manual_masks: Optional[List[List[List[int]]]] = None


class MoveResponse(BaseModel):
    image: str
    message: str
    metrics: List[Metric]


class InpaintRequest(BaseModel):
    image_name: str
    masks_ids: List[int]
    prompt: str
    model_type: str
    manual_masks: Optional[List[List[List[int]]]] = None


class InpaintResponse(BaseModel):
    image: str
    message: str
    metrics: List[Metric]


class SetImageRequest(BaseModel):
    image: str  # base64 encoded image


class SetMasksRequest(BaseModel):
    image_name: str
    masks: List[List[List[int]]]


class StylizeRequest(BaseModel):
    image: str
    target_image: Optional[str] = None
    prompt: Optional[str] = None
    style: Optional[str] = None


class ImgToImgRequest(BaseModel):
    image: str
    prompt: str