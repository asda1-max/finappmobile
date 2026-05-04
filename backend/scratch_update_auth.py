import sqlite3
import re

with open("fastapi_app.py", "r") as f:
    content = f.read()

# 1. Update _init_db to add minat
init_db_old = """
        try:
            conn.execute("ALTER TABLE users ADD COLUMN portfolio_goals TEXT")
        except sqlite3.OperationalError:
            pass
"""
init_db_new = """
        try:
            conn.execute("ALTER TABLE users ADD COLUMN portfolio_goals TEXT")
        except sqlite3.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE users ADD COLUMN minat TEXT")
        except sqlite3.OperationalError:
            pass
"""
if init_db_old in content:
    content = content.replace(init_db_old, init_db_new)

# 2. Update the get_current_user payload
get_user_old = """
    return {
        "user_id": user["id"], 
        "username": user["username"], 
        "email": user["email"],
        "profile_pic": user.get("profile_pic"),
        "portfolio_goals": user.get("portfolio_goals")
    }
"""
get_user_new = """
    return {
        "user_id": user["id"], 
        "username": user["username"], 
        "email": user["email"],
        "profile_pic": user.get("profile_pic"),
        "portfolio_goals": user.get("portfolio_goals"),
        "minat": user.get("minat")
    }
"""
content = content.replace(get_user_old, get_user_new)

# 3. Update the update_profile endpoint
update_profile_old_def = """
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
"""

update_profile_new_def = """
class UpdateProfilePayload(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = None
    portfolio_goals: Optional[str] = None
    minat: Optional[str] = None

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

    try:
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
            if payload.minat is not None:
                updates.append("minat = ?")
                params.append(payload.minat.strip())
                
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
            "portfolio_goals": updated_user.get("portfolio_goals"),
            "minat": updated_user.get("minat")
        }
    except sqlite3.IntegrityError as e:
        raise HTTPException(status_code=400, detail="Username or email already exists.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to update profile: {str(e)}")

@app.get("/hybrid-preset")
async def get_hybrid_preset(goals: str = Query(None), minat: str = Query(None)):
    '''
    Returns an optimized preset for Hybrid Mode depending on selected goals and minat.
    Weights Order: 
    1. ROE, 2. EPS Growth, 3. PER, 4. PBV, 5. DER, 6. Current Ratio, 7. Div Yield, 8. Operating Margin
    '''
    # Default fallback
    use_cagr_weights = [0.18, 0.06, 0.12, 0.20, 0.15, 0.15, 0.08, 0.12]
    no_cagr_weights = [0.20, 0.00, 0.10, 0.30, 0.20, 0.20, 0.00, 0.00]
    rec, buy, risk = 0.52, 0.44, 0.34
    
    goals = goals.lower() if goals else ""
    minat = minat.lower() if minat else ""
    
    # Simple logic mapping
    if "aggressive" in goals or "tech" in minat or "growth" in minat:
        use_cagr_weights = [0.15, 0.25, 0.10, 0.10, 0.10, 0.10, 0.05, 0.15]
        no_cagr_weights = [0.20, 0.00, 0.15, 0.15, 0.10, 0.10, 0.10, 0.20]
        rec, buy, risk = 0.60, 0.50, 0.35 # Higher risk tolerance
    elif "preservation" in goals or "dividend" in minat or "value" in minat:
        use_cagr_weights = [0.15, 0.05, 0.20, 0.20, 0.10, 0.10, 0.15, 0.05]
        no_cagr_weights = [0.20, 0.00, 0.25, 0.25, 0.10, 0.10, 0.10, 0.00]
        rec, buy, risk = 0.55, 0.48, 0.40 # Requires safer plays

    return {
        "use_cagr": {
            "weights": use_cagr_weights,
            "recommended": rec,
            "buy": buy,
            "risk": risk
        },
        "no_cagr": {
            "weights": no_cagr_weights,
            "recommended": rec + 0.1,
            "buy": buy + 0.1,
            "risk": risk + 0.1
        }
    }
"""
content = content.replace(update_profile_old_def, update_profile_new_def)

with open("fastapi_app.py", "w") as f:
    f.write(content)

