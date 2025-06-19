-- BEFORE INSERT: проверка количества и обновление цены
CREATE OR REPLACE FUNCTION check_order_item_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_price DECIMAL(10, 2);
    v_stock INT;
BEGIN
    -- Получение текущей цены и количества товара
    SELECT price, stock_quantity INTO v_price, v_stock
    FROM products
    WHERE product_id = NEW.product_id;
    
    -- Проверка наличия товара
    IF v_stock < NEW.quantity THEN
        RAISE EXCEPTION 'Недостаточно товара на складе (доступно: %, запрошено: %)', 
            v_stock, NEW.quantity;
    END IF;
    
    -- Установка цены на момент заказа
    NEW.unit_price := v_price;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER order_items_before_insert
BEFORE INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION check_order_item_before_insert();

-- BEFORE UPDATE: запрет изменения заказа
CREATE OR REPLACE FUNCTION prevent_order_item_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Изменение позиций заказа запрещено';
    RETURN NULL;
END;
$$;

CREATE TRIGGER order_items_before_update
BEFORE UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION prevent_order_item_update();

-- AFTER DELETE: обновление общего количества заказа
CREATE OR REPLACE FUNCTION update_order_after_item_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Обновление общей суммы заказа
    UPDATE orders
    SET total_amount = total_amount - (OLD.quantity * OLD.unit_price)
    WHERE order_id = OLD.order_id;
    
    -- Возврат товара на склад
    UPDATE products
    SET stock_quantity = stock_quantity + OLD.quantity
    WHERE product_id = OLD.product_id;
    
    RETURN OLD;
END;
$$;

CREATE TRIGGER order_items_after_delete
AFTER DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_order_after_item_delete();