import sys

with open('fastapi_app.py', 'r') as f:
    content = f.read()

get_user_code = """
    return {"user_id": user["id"], "username": user["username"], "email": user["email"]}
"""
new_get_user_code = """
    return {
        "user_id": user["id"], 
        "username": user["username"], 
        "email": user["email"],
        "profile_pic": user.get("profile_pic"),
        "portfolio_goals": user.get("portfolio_goals")
    }

class UpdateProfilePayload(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = None
    portfolio_goals: Optional[str] = None

@app.put("/auth/me")
async def update_profile(payload: UpdateProfilePayload, authorization: str = Query(None, alias="token")):
    if not authorization:
        raise HTTPException(status_code=401, detail="Token required")
    token = authorization.replace("Bearer ", "") if authorization.startswith("Bearer ") else authorization
    decoded = _verify_jwt(token)
    if not decoded:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    
    user_id = decoded.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    with _db_connect() as conn:
        user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        user = dict(user)
        
        updates = []
        params = []
        if payload.username:
            updates.append("username = ?")
            params.append(payload.username.strip().lower())
        if payload.email:
            updates.append("email = ?")
            params.append(payload.email.strip())
        if payload.password:
            import bcrypt
            updates.append("password_hash = ?")
            params.append(bcrypt.hashpw(payload.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8"))
        if payload.portfolio_goals is not None:
            updates.append("portfolio_goals = ?")
            params.append(payload.portfolio_goals.strip())
            
        if updates:
            params.append(user_id)
            conn.execute(f"UPDATE users SET {', '.join(updates)} WHERE id = ?", params)
            
        updated_user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        updated_user = dict(updated_user)
        
    return {
        "user_id": updated_user["id"],
        "username": updated_user["username"],
        "email": updated_user["email"],
        "profile_pic": updated_user.get("profile_pic"),
        "portfolio_goals": updated_user.get("portfolio_goals")
    }

import shutil

@app.post("/auth/profile-picture")
async def upload_profile_picture(file: UploadFile = File(...), authorization: str = Query(None, alias="token")):
    if not authorization:
        raise HTTPException(status_code=401, detail="Token required")
    token = authorization.replace("Bearer ", "") if authorization.startswith("Bearer ") else authorization
    decoded = _verify_jwt(token)
    if not decoded:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    
    user_id = decoded.get("sub")
    
    filename = f"{user_id}_{file.filename}"
    file_path = uploads_dir / filename
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    file_url = f"/uploads/{filename}"
    with _db_connect() as conn:
        conn.execute("UPDATE users SET profile_pic = ? WHERE id = ?", (file_url, user_id))
        
    return {"profile_pic": file_url}

class FeedbackPayload(BaseModel):
    rating: str
    kesan: str
    saran: str

@app.post("/feedbacks")
async def create_feedback(payload: FeedbackPayload, authorization: str = Query(None, alias="token")):
    if not authorization:
        raise HTTPException(status_code=401, detail="Token required")
    token = authorization.replace("Bearer ", "") if authorization.startswith("Bearer ") else authorization
    decoded = _verify_jwt(token)
    if not decoded:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
        
    user_id = decoded.get("sub")
    feedback_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat()
    
    with _db_connect() as conn:
        conn.execute(
            "INSERT INTO feedbacks (id, user_id, rating, kesan, saran, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            (feedback_id, user_id, payload.rating, payload.kesan, payload.saran, created_at)
        )
        
    return {"id": feedback_id, "user_id": user_id, "rating": payload.rating, "kesan": payload.kesan, "saran": payload.saran, "created_at": created_at}

@app.get("/feedbacks")
async def get_feedbacks():
    with _db_connect() as conn:
        rows = conn.execute(
            "SELECT f.*, u.username, u.profile_pic FROM feedbacks f LEFT JOIN users u ON f.user_id = u.id ORDER BY f.created_at DESC"
        ).fetchall()
        return [dict(r) for r in rows]

@app.delete("/feedbacks/{feedback_id}")
async def delete_feedback(feedback_id: str, authorization: str = Query(None, alias="token")):
    if not authorization:
        raise HTTPException(status_code=401, detail="Token required")
    token = authorization.replace("Bearer ", "") if authorization.startswith("Bearer ") else authorization
    decoded = _verify_jwt(token)
    if not decoded:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
        
    user_id = decoded.get("sub")
    with _db_connect() as conn:
        fb = conn.execute("SELECT * FROM feedbacks WHERE id = ?", (feedback_id,)).fetchone()
        if not fb:
            raise HTTPException(status_code=404, detail="Feedback not found")
        if fb["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to delete this feedback")
            
        conn.execute("DELETE FROM feedbacks WHERE id = ?", (feedback_id,))
    return {"success": True}
"""

if get_user_code in content:
    content = content.replace(get_user_code, new_get_user_code)
    with open('fastapi_app.py', 'w') as f:
        f.write(content)
    print("Successfully patched fastapi_app.py")
else:
    print("Could not find insertion point!")
