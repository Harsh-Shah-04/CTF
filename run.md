cd "h:\Live_Projects\Hacking_projects\CTF\CTF"
python -m venv venv
.\venv\Scripts\Activate
pip install -r requirements.txt
python manage.py db upgrade
python serve.py