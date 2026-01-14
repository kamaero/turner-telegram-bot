import re

with open('bot.py', 'r') as f:
    content = f.read()

# Находим место после создания dp
pattern = r'(dp\s*=\s*Dispatcher\(\)[^\n]*\n)'
match = re.search(pattern, content)

if match:
    dp_line = match.group(1)
    insert_pos = match.end()
    
    # Добавляем регистрацию хендлеров engine_order
    new_code = dp_line + '''
# --- Регистрация хендлеров engine_order ---
print("Регистрация хендлеров engine_order...")
try:
    import engine_order
    # Регистрируем хендлеры
    dp.message.register(engine_order.cmd_engine, F.text == "/engine")
    dp.message.register(engine_order.engine_brand, FSMFilter(engine_order.EngineOrderForm.engine_brand), F.text)
    dp.message.register(engine_order.engine_year, FSMFilter(engine_order.EngineOrderForm.engine_year), F.text)
    dp.message.register(engine_order.engine_issue, FSMFilter(engine_order.EngineOrderForm.engine_issue), F.text)
    print("✅ Хендлеры engine_order зарегистрированы")
except Exception as e:
    print(f"❌ Ошибка регистрации engine_order: {e}")
'''
    
    # Заменяем в содержании
    content = content[:match.start()] + new_code + content[insert_pos:]
    
    with open('bot.py', 'w') as f:
        f.write(content)
    print("✅ bot.py обновлен")
else:
    print("❌ Не найдено создание dp в bot.py")
