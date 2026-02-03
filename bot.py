"""
Главный модуль Telegram-бота
Автор: Sergey Akulov, Kam Aero
GitHub: https://github.com/serg-akulov
"""
import asyncio
import logging
import re
import datetime
from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton, InputMediaPhoto
import config
import database

# --- Настройки ---
logging.basicConfig(level=logging.INFO)

# --- Глобальные переменные ---
bot = Bot(token=config.BOT_TOKEN)
dp = Dispatcher()

# --- Машина состояний (основной заказ - станочные работы) ---
class OrderForm(StatesGroup):
    photo = State()
    work_type = State()
    dimensions = State()
    conditions = State()
    urgency = State()
    extra_q = State()
    comment = State()

# --- Машина состояний для ремонта двигателя ---
class EngineOrderForm(StatesGroup):
    engine_brand = State()
    engine_year = State()
    engine_issue = State()
    engine_urgency = State()
    engine_comment = State()

class MachiningUnitForm(StatesGroup):
    category = State()
    brand = State()
    year = State()
    photo = State()
    comment = State()

# --- Машина состояний для ответов админа ---
class AdminReplyForm(StatesGroup):
    waiting_for_reply = State()

class CommentForm(StatesGroup):
    waiting_comment = State()
    waiting_engine_comment = State()

# --- Вспомогательные функции ---
def get_text(key: str) -> str:
    """Получает текст из базы по ключу. Если нет — возвращает заглушку."""
    cfg = database.get_bot_config()
    return cfg.get(key, f"[NO_DB_TEXT: {key}]")

def get_config_bool(key: str) -> bool:
    """Преобразует строку из базы в bool."""
    return str(database.get_bot_config().get(key, '0')) == '1'

def safe_text(message: types.Message) -> str:
    """Безопасное извлечение текста из сообщения."""
    if message.text:
        return message.text
    if message.caption:
        return message.caption
    if message.sticker:
        return "[Стикер]"
    if message.photo:
        return "[Фото]"
    return "[Неизвестно]"

# --- Клавиатуры ---
def kb_main_menu():
    """Основное меню с двумя большими кнопками"""
    buttons = [
        [KeyboardButton(text="🔧 Ремонт двигателя")],
        [KeyboardButton(text="⚙️ Станочные работы")]
    ]
    return ReplyKeyboardMarkup(keyboard=buttons, resize_keyboard=True, one_time_keyboard=False)

def kb_photo_step():
    buttons = [[KeyboardButton(text="✅ Все фото отправлены")]]
    if not get_config_bool('is_photo_required'):
        buttons.append([KeyboardButton(text=get_text('btn_skip_photo'))])
    return ReplyKeyboardMarkup(keyboard=buttons, resize_keyboard=True, one_time_keyboard=True)

def kb_work_type():
    buttons = [
        [InlineKeyboardButton(text=get_text('btn_type_repair'), callback_data="type_repair")],
        [InlineKeyboardButton(text=get_text('btn_type_copy'), callback_data="type_copy")],
        [InlineKeyboardButton(text=get_text('btn_type_drawing'), callback_data="type_drawing")],
        [InlineKeyboardButton(text="🔩 Ремонт узлов", callback_data="type_units")]
    ]
    return InlineKeyboardMarkup(inline_keyboard=buttons)

def kb_cond():
    buttons = [
        [InlineKeyboardButton(text=get_text('btn_cond_rotation'), callback_data="cond_rotation")],
        [InlineKeyboardButton(text=get_text('btn_cond_static'), callback_data="cond_static")],
        [InlineKeyboardButton(text=get_text('btn_cond_impact'), callback_data="cond_impact")],
        [InlineKeyboardButton(text=get_text('btn_cond_unknown'), callback_data="cond_unknown")]
    ]
    return InlineKeyboardMarkup(inline_keyboard=buttons)

def kb_urgency():
    buttons = [
        [InlineKeyboardButton(text=get_text('btn_urgency_high'), callback_data="urgency_high")],
        [InlineKeyboardButton(text=get_text('btn_urgency_med'), callback_data="urgency_med")],
        [InlineKeyboardButton(text=get_text('btn_urgency_low'), callback_data="urgency_low")]
    ]
    return InlineKeyboardMarkup(inline_keyboard=buttons)

def kb_final_step():
    """Клавиатура для финального шага"""
    buttons = [
        [KeyboardButton(text="✅ Оформить заказ")],
        [KeyboardButton(text="✍️ Добавить комментарий")]
    ]
    return ReplyKeyboardMarkup(keyboard=buttons, resize_keyboard=True, one_time_keyboard=True)

def kb_unit_categories():
    buttons = [
        [InlineKeyboardButton(text="Головка блока цилиндров", callback_data="unit_hg")],
        [InlineKeyboardButton(text="Коленвал", callback_data="unit_crank")],
        [InlineKeyboardButton(text="Трансмиссия", callback_data="unit_trans")],
        [InlineKeyboardButton(text="Турбокомпрессор", callback_data="unit_turbo")],
        [InlineKeyboardButton(text="Топливная система", callback_data="unit_fuel")],
        [InlineKeyboardButton(text="Редукторы", callback_data="unit_gear")]
    ]
    return InlineKeyboardMarkup(inline_keyboard=buttons)

# --- Основные хендлеры ---
@dp.message(Command("start"))
async def cmd_start(message: types.Message, state: FSMContext):
    await state.clear()
    database.cancel_old_filling_orders(message.from_user.id)
    welcome = get_text('welcome_msg')
    await message.answer(
        f"{welcome}\n\nВыберите тип заказа:",
        reply_markup=kb_main_menu(),
        parse_mode="HTML"
    )

@dp.message(Command("cancel"))
async def cmd_cancel(message: types.Message, state: FSMContext):
    await state.clear()
    database.cancel_old_filling_orders(message.from_user.id)
    await message.answer(get_text('msg_order_canceled'), reply_markup=kb_main_menu())

@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    text = (
        "ℹ️ <b>Справка</b>\n\n"
        "Основные команды:\n"
        "• /start — начать оформление заказа\n"
        "• /cancel — отменить текущий заказ\n"
        "• /admin — панель администратора\n"
        "• /orders — последние заказы (админ)\n"
        "• /debugsettings — показывать текущие настройки\n"
        "• /adminstatus — статус привязки админа\n"
        "• /syncadmin — привязать chat_id к ник-админу\n"
        "• /listadmins — список админов (суперадмин)\n"
        "• /addadmin @ник — добавить админа (суперадмин)\n"
        "• /addadminphone +79999999999 — добавить админа по телефону (суперадмин)\n"
        "• /deladmin @ник — удалить админа (суперадмин)\n"
        "• /test — проверка работоспособности\n\n"
        "Выберите в меню:\n"
        "🔧 Ремонт двигателя или ⚙️ Станочные работы"
    )
    await message.answer(text, parse_mode="HTML")

# --- Кнопка: Ремонт двигателя ---
@dp.message(F.text == "🔧 Ремонт двигателя")
async def start_engine_flow(message: types.Message, state: FSMContext):
    """Начало процесса заказа ремонта двигателя"""
    print(f"DEBUG: Начало процесса ремонта двигателя для user_id={message.from_user.id}")

    # Создаем запись в базе данных
    user_id = message.from_user.id
    database.cancel_old_filling_orders(user_id)
    username = message.from_user.username or "NoNick"
    full_name = message.from_user.full_name

    order_id = database.create_order(user_id, username, full_name, order_type="engine_repair")
    print(f"DEBUG: Создан заказ №{order_id} для engine_repair")

    # Очищаем состояние и начинаем процесс
    await state.clear()
    await state.update_data(order_id=order_id)

    await message.answer(
        f"🆕 <b>Заказ №{order_id}</b>\n\n"
        "🔧 <b>Упрощённый заказ — ремонт двигателя</b>\n\n"
        "Введите марку и модель автомобиля (например: Toyota Camry):",
        parse_mode="HTML",
        reply_markup=types.ReplyKeyboardRemove()
    )
    await state.set_state(EngineOrderForm.engine_brand)

# --- Кнопка: Станочные работы ---
@dp.message(F.text == "⚙️ Станочные работы")
async def start_machining_flow(message: types.Message, state: FSMContext):
    await state.clear()
    user_id = message.from_user.id
    database.cancel_old_filling_orders(user_id)
    username = message.from_user.username or "NoNick"
    full_name = message.from_user.full_name

    order_id = database.create_order(user_id, username, full_name, order_type="machining")
    await state.update_data(order_id=order_id, photo_ids=[])
    await message.answer(f"🆕 <b>Заказ №{order_id}</b>", parse_mode="HTML")
    await message.answer(get_text('step_photo_text'), reply_markup=kb_photo_step(), parse_mode="Markdown")
    await state.set_state(OrderForm.photo)

# --- Основной заказ: фото → тип → размеры → условия → срочность → коммент ---
@dp.message(OrderForm.photo, F.photo)
async def process_photo(message: types.Message, state: FSMContext):
    data = await state.get_data()
    p_ids = data.get('photo_ids', [])
    p_ids.append(message.photo[-1].file_id)
    await state.update_data(photo_ids=p_ids)
    await message.answer(f"📸 Фото {len(p_ids)} принято.", reply_markup=kb_photo_step())

@dp.message(OrderForm.photo)
async def process_photo_done(message: types.Message, state: FSMContext):
    txt = safe_text(message)
    data = await state.get_data()
    p_ids = data.get('photo_ids', [])
    skip_btn = get_text('btn_skip_photo')

    if txt == "✅ Все фото отправлены":
        if not p_ids:
            await message.answer("⚠️ Вы не загрузили ни одного фото.")
            return
        database.update_order_field(data['order_id'], 'photo_file_id', ",".join(p_ids))
        await message.answer("👍 Фото приняты.", reply_markup=types.ReplyKeyboardRemove())
        await ask_work_type(message, state)
    elif txt == skip_btn and not get_config_bool('is_photo_required'):
        await message.answer("👍 Ок, без фото.", reply_markup=types.ReplyKeyboardRemove())
        await ask_work_type(message, state)
    else:
        await check_lost_state(message, state)

async def ask_work_type(message: types.Message, state: FSMContext):
    await message.answer(get_text('step_type_text'), reply_markup=kb_work_type(), parse_mode="Markdown")
    await state.set_state(OrderForm.work_type)

@dp.callback_query(OrderForm.work_type)
async def process_work_type(callback: types.CallbackQuery, state: FSMContext):
    map_types = {
        'type_repair': 'btn_type_repair',
        'type_copy': 'btn_type_copy',
        'type_drawing': 'btn_type_drawing'
    }
    if callback.data == "type_units":
        data = await state.get_data()
        order_id = data['order_id']
        database.update_order_field(order_id, 'order_type', 'machining_unit')
        await callback.message.edit_text("✅ Ремонт узлов")
        await callback.message.answer("Выберите категорию:", reply_markup=kb_unit_categories())
        await state.set_state(MachiningUnitForm.category)
        await callback.answer()
        return
    key = map_types.get(callback.data)
    if not key:
        await callback.answer("Неверный выбор")
        return
    human = get_text(key)
    order_id = (await state.get_data())['order_id']
    database.update_order_field(order_id, 'work_type', human)
    await callback.message.edit_text(f"✅ {human}")
    await callback.message.answer(get_text('step_dim_text'), parse_mode="Markdown")
    await state.set_state(OrderForm.dimensions)

@dp.callback_query(MachiningUnitForm.category)
async def unit_category_handler(callback: types.CallbackQuery, state: FSMContext):
    cat_map = {
        'unit_hg': "Головка блока цилиндров",
        'unit_crank': "Коленвал",
        'unit_trans': "Трансмиссия",
        'unit_turbo': "Турбокомпрессор",
        'unit_fuel': "Топливная система",
        'unit_gear': "Редукторы"
    }
    if callback.data not in cat_map:
        await callback.answer("Неверный выбор")
        return
    cat = cat_map[callback.data]
    order_id = (await state.get_data())['order_id']
    database.update_order_field(order_id, 'work_type', cat)
    await callback.message.edit_text(f"✅ Категория: {cat}")
    await callback.message.answer("Введите марку и модель автомобиля:")
    await state.set_state(MachiningUnitForm.brand)
    await callback.answer()

@dp.message(MachiningUnitForm.brand)
async def unit_brand_handler(message: types.Message, state: FSMContext):
    brand = message.text.strip()[:100]
    if len(brand) < 2:
        await message.answer("Введите корректную марку и модель.")
        return
    order_id = (await state.get_data())['order_id']
    database.update_order_field(order_id, 'car_brand', brand)
    await state.update_data(unit_brand=brand, unit_photo_ids=[])
    await message.answer("Введите год выпуска (ГГГГ):")
    await state.set_state(MachiningUnitForm.year)

@dp.message(MachiningUnitForm.year)
async def unit_year_handler(message: types.Message, state: FSMContext):
    year_text = message.text.strip()
    if not re.match(r"^(19|20)\d{2}$", year_text):
        await message.answer("Введите корректный год (например: 2015).")
        return
    year = int(year_text)
    current_year = datetime.datetime.now().year
    if year < 1900 or year > current_year:
        await message.answer(f"Введите реальный год выпуска (1900-{current_year}).")
        return
    order_id = (await state.get_data())['order_id']
    database.update_order_field(order_id, 'car_year', year_text)
    await message.answer("Загрузите фото при необходимости, затем нажмите кнопку.", reply_markup=kb_photo_step())
    await state.set_state(MachiningUnitForm.photo)

@dp.message(MachiningUnitForm.photo, F.photo)
async def unit_photo_collect(message: types.Message, state: FSMContext):
    data = await state.get_data()
    p_ids = data.get('unit_photo_ids', [])
    p_ids.append(message.photo[-1].file_id)
    await state.update_data(unit_photo_ids=p_ids)
    await message.answer(f"Фото {len(p_ids)} принято.", reply_markup=kb_photo_step())

@dp.message(MachiningUnitForm.photo)
async def unit_photo_done(message: types.Message, state: FSMContext):
    txt = safe_text(message)
    data = await state.get_data()
    p_ids = data.get('unit_photo_ids', [])
    skip_btn = get_text('btn_skip_photo')
    order_id = data['order_id']
    if txt == "✅ Все фото отправлены":
        if p_ids:
            database.update_order_field(order_id, 'photo_file_id', ",".join(p_ids))
        await message.answer("Фото сохранены.", reply_markup=types.ReplyKeyboardRemove())
        await message.answer("Добавьте комментарий или оформите заказ.", reply_markup=kb_final_step(), parse_mode="Markdown")
        await state.set_state(MachiningUnitForm.comment)
    elif txt == skip_btn and not get_config_bool('is_photo_required'):
        await message.answer("Ок, без фото.", reply_markup=types.ReplyKeyboardRemove())
        await message.answer("Добавьте комментарий или оформите заказ.", reply_markup=kb_final_step(), parse_mode="Markdown")
        await state.set_state(MachiningUnitForm.comment)
    else:
        await message.answer("Загрузите фото или используйте кнопку.")

@dp.message(MachiningUnitForm.comment)
async def unit_comment_handler(message: types.Message, state: FSMContext):
    data = await state.get_data()
    txt = safe_text(message)
    order_id = data['order_id']
    if txt == "✅ Оформить заказ":
        final_comm = "Нет дополнительных комментариев"
        await finish_order(order_id, final_comm, message, state)
        return
    elif txt == "✍️ Добавить комментарий":
        await message.answer("Напишите ваш комментарий:", parse_mode="Markdown", reply_markup=types.ReplyKeyboardRemove())
        await state.set_state(CommentForm.waiting_comment)
        return
    else:
        await finish_order(order_id, txt, message, state)
        return

@dp.message(OrderForm.dimensions)
async def process_dimensions(message: types.Message, state: FSMContext):
    txt = safe_text(message)
    order_id = (await state.get_data())['order_id']
    database.update_order_field(order_id, 'dimensions_info', txt)
    await message.answer(get_text('step_cond_text'), reply_markup=kb_cond(), parse_mode="Markdown")
    await state.set_state(OrderForm.conditions)

@dp.callback_query(OrderForm.conditions)
async def process_conditions(callback: types.CallbackQuery, state: FSMContext):
    map_cond = {
        'cond_rotation': 'btn_cond_rotation',
        'cond_static': 'btn_cond_static',
        'cond_impact': 'btn_cond_impact',
        'cond_unknown': 'btn_cond_unknown'
    }
    human = get_text(map_cond.get(callback.data))
    order_id = (await state.get_data())['order_id']
    database.update_order_field(order_id, 'conditions', human)
    await callback.message.edit_text(f"✅ {human}")
    await callback.message.answer(get_text('step_urgency_text'), reply_markup=kb_urgency(), parse_mode="Markdown")
    await state.set_state(OrderForm.urgency)

@dp.callback_query(OrderForm.urgency)
async def process_urgency(callback: types.CallbackQuery, state: FSMContext):
    map_urg = {
        'urgency_high': 'btn_urgency_high',
        'urgency_med': 'btn_urgency_med',
        'urgency_low': 'btn_urgency_low'
    }
    human = get_text(map_urg.get(callback.data))
    order_id = (await state.get_data())['order_id']
    database.update_order_field(order_id, 'urgency', human)
    await callback.message.edit_text(f"✅ {human}")
    if get_config_bool('step_extra_enabled'):
        await callback.message.answer(get_text('step_extra_text'), parse_mode="Markdown")
        await state.set_state(OrderForm.extra_q)
    else:
        await ask_final(callback.message, state)

@dp.message(OrderForm.extra_q)
async def process_extra(message: types.Message, state: FSMContext):
    txt = safe_text(message)
    await state.update_data(temp_comment=f"Доп: {txt}\n")
    await ask_final(message, state)

async def ask_final(message: types.Message, state: FSMContext):
    """Финальный шаг с кнопками"""
    await message.answer(
        "🎯 *Почти готово!*\n\n"
        "Хотите добавить комментарий к заказу? Например:\n"
        "• Особые требования\n"
        "• Пожелания по срокам\n"
        "• Контакт для связи\n\n"
        "Если всё ясно — просто нажмите кнопку '✅ Оформить заказ'",
        parse_mode="Markdown",
        reply_markup=kb_final_step()
    )
    await state.set_state(OrderForm.comment)

@dp.message(OrderForm.comment)
async def process_comment(message: types.Message, state: FSMContext):
    """Обработка финального шага с кнопками"""
    data = await state.get_data()
    txt = safe_text(message)
    order_id = data['order_id']

    # Если нажали "✅ Оформить заказ"
    if txt == "✅ Оформить заказ":
        final_comm = data.get('temp_comment', '') + "Нет дополнительных комментариев"
        await finish_order(order_id, final_comm, message, state)
        return

    # Если нажали "✍️ Добавить комментарий"
    elif txt == "✍️ Добавить комментарий":
        await message.answer(
            "✍️ Напишите ваш комментарий к заказу:\n\n"
            "(Можете написать любые пожелания, вопросы или оставить пустым)",
            parse_mode="Markdown",
            reply_markup=types.ReplyKeyboardRemove()
        )
        # Меняем состояние на ожидание комментария
        await state.set_state(CommentForm.waiting_comment)
        return

    else:
        # Это пользовательский комментарий (если сразу написали текст вместо кнопки)
        final_comm = data.get('temp_comment', '') + txt
        await finish_order(order_id, final_comm, message, state)
        return

@dp.message(CommentForm.waiting_comment)
async def process_user_comment(message: types.Message, state: FSMContext):
    """Обработка пользовательского комментария"""
    data = await state.get_data()
    txt = safe_text(message)
    order_id = data['order_id']

    final_comm = data.get('temp_comment', '') + txt

    # Завершаем заказ
    await finish_order(order_id, final_comm, message, state)

async def finish_order(order_id: int, comment: str, message: types.Message, state: FSMContext):
    """Завершение оформления заказа"""
    database.update_order_field(order_id, 'comment', comment)
    database.finish_order_creation(order_id)

    await message.answer(
        "🎉 *Заказ успешно оформлен!*\n\n"
        f"📋 *Номер заказа:* №{order_id}\n\n"
        "Мы свяжемся с вами в ближайшее время для уточнения деталей.\n"
        "Спасибо за заказ! ✅",
        reply_markup=kb_main_menu(),
        parse_mode="Markdown"
    )

    await notify_admin(order_id)
    await state.clear()

async def notify_admin(order_id: int):
    ids = database.get_admin_chat_ids()
    if not ids:
        return
    order = database.get_order(order_id)

    # Создаем кнопку "Ответить" под сообщением
    reply_markup = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="💬 Ответить клиенту", callback_data=f"reply_{order_id}")]
    ])

    if order.get('order_type') == 'machining_unit':
        text = (f"🔔 <b>НОВЫЙ ЗАКАЗ №{order['id']}</b>\n"
                f"Тип: Ремонт узла\n"
                f"👤: {order['full_name']} (@{order['username']})\n"
                f"🔩 Узел: {order['work_type']}\n"
                f"🚗 Марка: {order.get('car_brand') or 'Не указано'}\n"
                f"📅 Год: {order.get('car_year') or 'Не указано'}\n"
                f"⏳: {order['urgency'] or 'Не указано'}\n"
                f"📝: {order['comment'] or 'Нет комментариев'}")
    else:
        text = (f"🔔 <b>НОВЫЙ ЗАКАЗ №{order['id']}</b>\n"
                f"Тип: Станочные работы\n"
                f"👤: {order['full_name']} (@{order['username']})\n"
                f"🛠: {order['work_type']}\n"
                f"📏: {order['dimensions_info']}\n"
                f"⚙️: {order['conditions']}\n"
                f"⏳: {order['urgency']}\n"
                f"📝: {order['comment'] or 'Нет комментариев'}")

    p_ids = order['photo_file_id'].split(',') if order['photo_file_id'] else []
    for aid in ids:
        try:
            if len(p_ids) > 1:
                mg = [InputMediaPhoto(media=pid) for pid in p_ids]
                await bot.send_media_group(aid, media=mg)
                await bot.send_message(aid, text, parse_mode="HTML", reply_markup=reply_markup)
            elif len(p_ids) == 1:
                await bot.send_photo(aid, p_ids[0], caption=text, parse_mode="HTML", reply_markup=reply_markup)
            else:
                await bot.send_message(aid, text, parse_mode="HTML", reply_markup=reply_markup)
        except Exception as e:
            logging.error(f"Ошибка отправки админу: {e}")

# --- Админка ---
@dp.message(Command("iamadmin"))
async def cmd_admin_auth(message: types.Message):
    args = message.text.split()
    if len(args) > 1 and args[1] == config.BOT_ADMIN_PASSWORD:
        ok = database.add_admin(message.chat.id, message.from_user.username or None, message.from_user.full_name or None)
        if ok:
            await message.answer("✅ Админ авторизован.")
        else:
            await message.answer("❌ Достигнут лимит админов (до 10).")
    else:
        await message.answer("❌ Неверный пароль.")

@dp.message(F.reply_to_message)
async def admin_reply_handler(message: types.Message):
    """Старый обработчик Reply (оставлен для совместимости)"""
    if not database.is_admin(message.chat.id, message.from_user.username):
        return
    orig = message.reply_to_message.caption or message.reply_to_message.text
    if not orig:
        return
    match = re.search(r"(?:№|No|Num|Заказ)\s*[:#]?\s*(\d+)", orig, re.IGNORECASE)
    if not match:
        return
    oid = int(match.group(1))
    order = database.get_order(oid)
    if not order:
        return
    try:
        if message.text:
            await bot.send_message(order['user_id'], f"👨‍🔧 <b>Мастер:</b>\n{message.text}", parse_mode="HTML")
        else:
            await message.copy_to(order['user_id'])
        await message.react([types.ReactionTypeEmoji(emoji="👍")])
    except Exception as e:
        await message.answer(f"❌ Ошибка: {e}")

# --- Восстановление сессии ---
async def check_lost_state(message: types.Message, state: FSMContext = None):
    filling_id = database.get_active_order_id(message.from_user.id)
    if filling_id:
        order = database.get_order(filling_id)
        has_photos = bool(order['photo_file_id'])
        if not has_photos and not get_config_bool('is_photo_required'):
            if state:
                await state.update_data(order_id=filling_id)
                await state.set_state(OrderForm.photo)
            await process_photo_done(message, state)
            return
        if not order['work_type']:
            await message.answer("⚠️ Восстановление: выберите тип работы", reply_markup=kb_work_type())
            if state: await state.set_state(OrderForm.work_type)
        elif not order['dimensions_info']:
            database.update_order_field(filling_id, 'dimensions_info', safe_text(message))
            await message.answer("✅ Размеры записаны. Условия?", reply_markup=kb_cond())
            if state: await state.set_state(OrderForm.conditions)
        else:
            await process_comment(message, state or FSMContext(storage=dp.storage, key=None))

# --- Админские команды ---
@dp.message(Command("admin"))
async def cmd_admin_panel(message: types.Message):
    """Админ-панель"""
    if not database.is_admin(message.chat.id, message.from_user.username):
        return

    buttons = [
        [InlineKeyboardButton(text="📊 Статистика", callback_data="admin_stats")],
        [InlineKeyboardButton(text="📋 Активные заказы", callback_data="admin_active")],
        [InlineKeyboardButton(text="👥 Последние клиенты", callback_data="admin_clients")],
    ]

    await message.answer(
        "🛠 <b>Админ-панель</b>\n\n"
        "Выберите действие:",
        reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons),
        parse_mode="HTML"
    )

@dp.callback_query(F.data.startswith("admin_"))
async def admin_callback_handler(callback: types.CallbackQuery):
    """Обработка админских кнопок"""
    if not database.is_admin(callback.message.chat.id, callback.from_user.username):
        await callback.answer("❌ Нет доступа")
        return

    action = callback.data

    if action == "admin_stats":
        # Статистика
        stats = database.get_stats()
        await callback.message.edit_text(
            f"📊 <b>Статистика</b>\n\n"
            f"Всего заказов: {stats.get('total_orders', 0)}\n"
            f"Станочные работы: {stats.get('machining_orders', 0)}\n"
            f"Ремонт двигателя: {stats.get('engine_orders', 0)}\n"
            f"Активные: {stats.get('active_orders', 0)}\n"
            f"Завершенные: {stats.get('completed_orders', 0)}",
            parse_mode="HTML"
        )

    elif action == "admin_active":
        # Активные заказы
        active_orders = database.get_active_orders()
        if not active_orders:
            text = "📭 Нет активных заказов"
        else:
            text = "📋 <b>Активные заказы:</b>\n\n"
            for order in active_orders[:10]:  # первые 10
                text += f"🔸 №{order['id']}: {order['order_type']} - {order['created_at']}\n"

        await callback.message.edit_text(text, parse_mode="HTML")

    elif action == "admin_clients":
        # Последние клиенты
        recent_clients = database.get_recent_clients()
        if not recent_clients:
            text = "👥 Нет клиентов"
        else:
            text = "👥 <b>Последние клиенты:</b>\n\n"
            for client in recent_clients[:10]:
                text += f"👤 {client['full_name']} (@{client['username']})\n"
                text += f"   Заказов: {client['order_count']}\n"
                text += f"   Последний: {client['last_order']}\n\n"

        await callback.message.edit_text(text, parse_mode="HTML")

    await callback.answer()

@dp.message(Command("debugsettings"))
async def cmd_debug_settings(message: types.Message):
    """Отладка настроек"""
    cfg = database.get_bot_config()

    text = "⚙️ <b>Текущие настройки:</b>\n\n"
    for key, value in cfg.items():
        text += f"<code>{key}</code>: {value}\n"

    text += f"\n📱 <b>Ваш Chat ID:</b> {message.chat.id}"

    await message.answer(text, parse_mode="HTML")

@dp.message(Command("orders"))
async def cmd_admin_orders(message: types.Message):
    """Показать последние заказы"""
    cfg = database.get_bot_config()
    if str(message.chat.id) != str(cfg.get("admin_chat_id", "0")):
        return

    orders = database.get_recent_orders(limit=10)

    if not orders:
        await message.answer("📭 Нет заказов")
        return

    text = "📋 <b>Последние заказы:</b>\n\n"
    for order in orders:
        status = "✅" if order['status'] == 'completed' else "🔄"
        text += f"{status} <b>№{order['id']}</b> - {order['order_type']}\n"
        text += f"👤 {order['full_name']} (@{order['username']})\n"
        text += f"📅 {order['created_at']}\n"
        text += f"📝 {order['comment'][:50]}...\n\n"

    await message.answer(text, parse_mode="HTML")

# --- Тестовые команды ---
@dp.message(F.text == "/test")
async def test_command(message: types.Message):
    await message.answer("✅ Бот работает! Команда /test получена.")

@dp.message(F.text == "/engine_test")
async def engine_test_command(message: types.Message):
    await message.answer("✅ Проверка модуля engine_order...")
    try:
        import engine_order
        await message.answer("✅ Модуль engine_order загружен успешно!")
    except Exception as e:
        await message.answer(f"❌ Ошибка загрузки модуля: {e}")

@dp.message(Command("adminstatus"))
async def cmd_admin_status(message: types.Message):
    """Проверка статуса админа"""
    ids = database.get_admin_chat_ids()
    if not ids:
        await message.answer("❌ Админы не установлены. Используйте /iamadmin ПАРОЛЬ")
    else:
        await message.answer(f"✅ Админы: {', '.join(map(str, ids))}\nВаш Chat ID: {message.chat.id}")

# --- Хендлеры для ремонта двигателя ---
@dp.message(EngineOrderForm.engine_brand)
async def engine_brand_handler(message: types.Message, state: FSMContext):
    """Обработка марки автомобиля"""
    print(f"DEBUG: engine_brand_handler вызван с текстом: {message.text}")

    brand = message.text.strip()[:100]

    if len(brand) < 2:
        await message.answer("❌ Слишком короткое название. Введите марку и модель (например: Toyota Camry):")
        return

    # Сохраняем в БД
    user_data = await state.get_data()
    order_id = user_data.get('order_id')
    if order_id:
        database.update_order_field(order_id, 'car_brand', brand)

    await state.update_data(engine_brand=brand)
    await message.answer(f"✅ Марка: {brand}\n\n📅 Введите год выпуска (например: 2015):")
    await state.set_state(EngineOrderForm.engine_year)

@dp.message(EngineOrderForm.engine_year)
async def engine_year_handler(message: types.Message, state: FSMContext):
    """Обработка года выпуска"""
    print(f"DEBUG: engine_year_handler вызван с текстом: {message.text}")

    year_text = message.text.strip()

    if not re.match(r"^(19|20)\d{2}$", year_text):
        await message.answer("❌ Введите корректный год в формате ГГГГ (например: 2010).")
        return

    year = int(year_text)
    current_year = datetime.datetime.now().year
    if year < 1900 or year > current_year:
        await message.answer(f"❌ Введите реальный год выпуска (1900-{current_year}).")
        return

    # Сохраняем в БД
    user_data = await state.get_data()
    order_id = user_data.get('order_id')
    if order_id:
        database.update_order_field(order_id, 'car_year', year_text)

    await state.update_data(engine_year=year_text)
    await message.answer(f"✅ Год: {year_text}\n\n🔧 Опишите проблему своими словами:")
    await state.set_state(EngineOrderForm.engine_issue)

@dp.message(EngineOrderForm.engine_issue)
async def engine_issue_handler(message: types.Message, state: FSMContext):
    """Обработка описания проблемы"""
    print(f"DEBUG: engine_issue_handler вызван с текстом: {message.text[:50]}...")

    issue = message.text.strip()

    if len(issue) < 5:
        await message.answer("❌ Опишите подробнее (минимум 5 символов).")
        return

    # Сохраняем в БД
    user_data = await state.get_data()
    order_id = user_data.get('order_id')
    if order_id:
        database.update_order_field(order_id, 'engine_issue', issue)

    await state.update_data(engine_issue=issue)
    await message.answer("✅ Проблема сохранена!\n\n⚡ Выберите срочность:", reply_markup=kb_urgency())
    await state.set_state(EngineOrderForm.engine_urgency)

@dp.callback_query(EngineOrderForm.engine_urgency)
async def engine_urgency_handler(callback: types.CallbackQuery, state: FSMContext):
    """Обработка выбора срочности"""
    print(f"DEBUG: engine_urgency_handler вызван с callback.data: {callback.data}")

    urgency_map = {
        'urgency_high': 'Высокая',
        'urgency_med': 'Средняя',
        'urgency_low': 'Низкая'
    }

    if callback.data not in urgency_map:
        await callback.answer("❌ Неверный выбор")
        return

    urgency = urgency_map[callback.data]
    await state.update_data(engine_urgency=urgency)

    user_data = await state.get_data()
    order_id = user_data.get('order_id')

    if order_id:
        database.update_order_field(order_id, 'urgency', urgency)

    await callback.message.edit_text(f"✅ Срочность: {urgency}")

    # Создаем клавиатуру для финального шага двигателя
    kb_engine_final = ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="✅ Оформить заказ")],
            [KeyboardButton(text="✍️ Добавить комментарий")]
        ],
        resize_keyboard=True,
        one_time_keyboard=True
    )

    await callback.message.answer(
        "🎯 *Почти готово!*\n\n"
        "Хотите добавить комментарий к заказу? Например:\n"
        "• Особые требования\n"
        "• Пожелания по срокам\n"
        "• Контакт для связи\n\n"
        "Если всё ясно — просто нажмите кнопку '✅ Оформить заказ'",
        parse_mode="Markdown",
        reply_markup=kb_engine_final
    )
    await state.set_state(EngineOrderForm.engine_comment)

@dp.message(EngineOrderForm.engine_comment)
async def engine_comment_handler(message: types.Message, state: FSMContext):
    """Обработка финального шага для ремонта двигателя"""
    txt = safe_text(message)
    user_data = await state.get_data()
    order_id = user_data.get('order_id')

    if not order_id:
        await message.answer("❌ Ошибка: заказ не найден")
        await state.clear()
        return

    # Если нажали "✅ Оформить заказ"
    if txt == "✅ Оформить заказ":
        comment = "Нет дополнительных комментариев"
        await finish_engine_order(order_id, comment, user_data, message, state)
        return

    # Если нажали "✍️ Добавить комментарий"
    elif txt == "✍️ Добавить комментарий":
        await message.answer(
            "✍️ Напишите ваш комментарий к заказу:\n\n"
            "(Можете написать любые пожелания, вопросы или оставить пустым)",
            parse_mode="Markdown",
            reply_markup=types.ReplyKeyboardRemove()
        )
        # Меняем состояние на ожидание комментария двигателя
        await state.set_state(CommentForm.waiting_engine_comment)
        return

    else:
        # Это пользовательский комментарий (если сразу написали текст)
        comment = txt
        await finish_engine_order(order_id, comment, user_data, message, state)
        return

@dp.message(CommentForm.waiting_engine_comment)
async def process_engine_user_comment(message: types.Message, state: FSMContext):
    """Обработка пользовательского комментария для двигателя"""
    user_data = await state.get_data()
    txt = safe_text(message)
    order_id = user_data.get('order_id')

    if not order_id:
        await message.answer("❌ Ошибка: заказ не найден")
        await state.clear()
        return

    await finish_engine_order(order_id, txt, user_data, message, state)

async def finish_engine_order(order_id: int, comment: str, user_data: dict, message: types.Message, state: FSMContext):
    """Завершение оформления заказа на ремонт двигателя"""
    # Обновляем комментарий в БД
    existing_comment = user_data.get('engine_issue', '')
    final_comment = f"{existing_comment}\n\nКомментарий: {comment}" if comment else existing_comment

    database.update_order_field(order_id, 'comment', final_comment)
    database.finish_order_creation(order_id)

    # Отправляем уведомление админу
    await notify_engine_admin(order_id, user_data)

    await message.answer(
        "🎉 <b>Заказ на ремонт двигателя успешно оформлен!</b>\n\n"
        f"📋 <b>Номер заказа:</b> №{order_id}\n"
        f"🚗 <b>Марка:</b> {user_data.get('engine_brand', 'Не указано')}\n"
        f"📅 <b>Год:</b> {user_data.get('engine_year', 'Не указано')}\n"
        f"🔧 <b>Проблема:</b> {user_data.get('engine_issue', 'Не указано')}\n"
        f"⏳ <b>Срочность:</b> {user_data.get('engine_urgency', 'Не указано')}\n\n"
        "Наш специалист свяжется с вами в ближайшее время.",
        reply_markup=kb_main_menu(),
        parse_mode="HTML"
    )

    await state.clear()

async def notify_engine_admin(order_id: int, user_data: dict):
    """Отправка уведомления админу о заказе двигателя"""
    ids = database.get_admin_chat_ids()
    if not ids:
        return

    order = database.get_order(order_id)

    # Создаем кнопку "Ответить" под сообщением
    reply_markup = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="💬 Ответить клиенту", callback_data=f"reply_{order_id}")]
    ])

    text = (f"🔔 <b>НОВЫЙ ЗАКАЗ №{order['id']}</b>\n"
            f"Тип: Ремонт двигателя\n"
            f"👤: {order['full_name']} (@{order['username']})\n"
            f"🚗 Марка: {user_data.get('engine_brand', 'Не указано')}\n"
            f"📅 Год: {user_data.get('engine_year', 'Не указано')}\n"
            f"🔧 Проблема: {user_data.get('engine_issue', 'Не указано')}\n"
            f"⏳ Срочность: {user_data.get('engine_urgency', 'Не указано')}\n"
            f"📝 Комментарий: {order['comment'] or 'Нет комментариев'}")

    for aid in ids:
        try:
            await bot.send_message(aid, text, parse_mode="HTML", reply_markup=reply_markup)
        except Exception as e:
            logging.error(f"Ошибка отправки админу (двигатель): {e}")

# обработчик ответа клиенту
@dp.callback_query(F.data.startswith("reply_"))
async def reply_to_order_handler(callback: types.CallbackQuery, state: FSMContext):
    """Обработка нажатия на кнопку 'Ответить клиенту'"""
    try:
        # Извлекаем ID заказа из callback_data
        order_id = int(callback.data.split("_")[1])
        order = database.get_order(order_id)

        if not order:
            await callback.answer("❌ Заказ не найден")
            return

        if not database.is_admin(callback.message.chat.id, callback.from_user.username):
            await callback.answer("❌ Нет доступа")
            return

        # Сохраняем данные для ответа
        await state.set_state(AdminReplyForm.waiting_for_reply)
        await state.update_data(
            reply_order_id=order_id,
            reply_user_id=order['user_id'],
            reply_message_id=callback.message.message_id
        )

        # Спрашиваем текст ответа
        await callback.message.answer(
            f"✍️ <b>Отправьте ответ клиенту по заказу №{order_id}:</b>\n\n"
            f"Клиент: {order['full_name']} (@{order['username']})\n\n"
            f"Напишите сообщение для клиента:",
            parse_mode="HTML"
        )

        await callback.answer()

    except Exception as e:
        logging.error(f"Ошибка обработки reply: {e}")
        await callback.answer("❌ Ошибка")

SUPERADMIN_ID = 11504

@dp.message(Command("listadmins"))
async def cmd_list_admins(message: types.Message):
    if message.from_user.id != SUPERADMIN_ID:
        return
    rows = database.list_admins()
    if not rows:
        await message.answer("Нет админов")
        return
    text = "Админы:\n\n"
    for r in rows:
        text += f"- {r.get('username') or 'нет'} | {r.get('chat_id') or 'нет'}\n"
    await message.answer(text)

@dp.message(Command("addadmin"))
async def cmd_add_admin(message: types.Message):
    if message.from_user.id != SUPERADMIN_ID:
        return
    args = message.text.split()
    if len(args) < 2:
        await message.answer("Укажите ник: /addadmin @username")
        return
    nick = args[1]
    ok = database.add_admin_by_username(nick)
    if ok:
        await message.answer("Админ добавлен")
    else:
        await message.answer("Не удалось добавить админа (возможно лимит 10)")

@dp.message(Command("deladmin"))
async def cmd_del_admin(message: types.Message):
    if message.from_user.id != SUPERADMIN_ID:
        return
    args = message.text.split()
    if len(args) < 2:
        await message.answer("Укажите ник: /deladmin @username")
        return
    nick = args[1]
    cnt = database.remove_admin_by_username(nick)
    if cnt > 0:
        await message.answer("Админ удален")
    else:
        await message.answer("Админ не найден")

@dp.message(Command("syncadmin"))
async def cmd_sync_admin(message: types.Message):
    username = message.from_user.username
    if not username:
        await message.answer("У вас нет @username. Установите ник в Telegram.")
        return
    ok = database.bind_admin_chat_id(username, message.chat.id, message.from_user.full_name or None)
    if ok:
        await message.answer("chat_id привязан к вашему нику. Вы админ.")
    else:
        await message.answer("Ник не найден в списке админов. Добавьте вас через /addadmin @ник у суперадмина.")

@dp.message(Command("addadminphone"))
async def cmd_add_admin_phone(message: types.Message):
    if message.from_user.id != SUPERADMIN_ID:
        return
    args = message.text.split()
    if len(args) < 2:
        await message.answer("Укажите номер: /addadminphone +79999999999 или 89999999999")
        return
    raw = args[1]
    norm = raw.strip()
    if re.match(r"^\+7\d{10}$", norm):
        phone = norm
    elif re.match(r"^8\d{10}$", norm):
        phone = "+7" + norm[1:]
    else:
        await message.answer("Неверный формат. Допустимо: +7XXXXXXXXXX или 8XXXXXXXXXX")
        return
    ok = database.add_admin_by_phone(phone)
    if ok:
        await message.answer(f"Админ по телефону {phone} добавлен")
    else:
        await message.answer("Не удалось добавить админа (возможно лимит 10)")

@dp.message(AdminReplyForm.waiting_for_reply)
async def process_admin_reply(message: types.Message, state: FSMContext):
    """Обработка текста ответа от админа"""
    data = await state.get_data()
    order_id = data.get('reply_order_id')
    user_id = data.get('reply_user_id')

    if not order_id or not user_id:
        await message.answer("❌ Ошибка: данные ответа потеряны")
        await state.clear()
        return

    try:
        # Отправляем сообщение клиенту
        await bot.send_message(
            user_id,
            f"👨‍🔧 <b>Ответ от мастера по заказу №{order_id}:</b>\n\n{message.text}",
            parse_mode="HTML"
        )

        # Подтверждаем админу
        await message.answer(f"✅ Ответ отправлен клиенту (заказ №{order_id})")

        # Меняем статус заказа на "discussion"
        database.update_order_field(order_id, 'status', 'discussion')

        # Удаляем кнопку "Ответить" из оригинального сообщения
        try:
            reply_message_id = data.get('reply_message_id')
            if reply_message_id:
                # Просто удаляем кнопку или добавляем текст об ответе
                await bot.edit_message_reply_markup(
                    chat_id=message.chat.id,
                    message_id=reply_message_id,
                    reply_markup=None  # Удаляем кнопку
                )
        except Exception as e:
            logging.error(f"Не удалось обновить сообщение: {e}")

    except Exception as e:
        await message.answer(f"❌ Ошибка отправки: {e}")

    await state.clear()

# --- Запуск бота ---
async def main():
    print("✅ Бот запущен...")
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
