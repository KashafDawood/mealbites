-- ============================================
-- MIGRATION: Add auto-profile creation and dish selection for suggestions
-- Date: 2026-01-29
-- ============================================

-- ============================================
-- 1. AUTO-CREATE EMPLOYEE PROFILE ON SIGNUP
-- ============================================

-- Function to automatically create employee profile when user signs up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, name, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
        'employee'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function after user creation
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

COMMENT ON FUNCTION handle_new_user() IS 'Automatically creates employee profile when new user signs up via auth.users';

-- ============================================
-- 2. ADD DISH REFERENCE TO MEAL SUGGESTIONS
-- ============================================

-- Add optional dish_id to meal_suggestions
-- This allows users to either:
--   - Select existing dish (dish_id is set, dish_name is copied)
--   - Suggest new dish (dish_id is NULL, dish_name is manually entered)
ALTER TABLE meal_suggestions
ADD COLUMN dish_id UUID REFERENCES dishes(id) ON DELETE SET NULL;

-- Add index for faster lookups
CREATE INDEX idx_meal_suggestions_dish_id ON meal_suggestions(dish_id);

-- Add constraint: Must have either dish_id OR dish_name (but not both empty)
ALTER TABLE meal_suggestions
ADD CONSTRAINT suggestion_must_have_dish 
CHECK (
    (dish_id IS NOT NULL) OR 
    (dish_name IS NOT NULL AND LENGTH(TRIM(dish_name)) > 0)
);

COMMENT ON COLUMN meal_suggestions.dish_id IS 'Optional reference to existing dish. If set, user selected existing dish. If NULL, user suggested new dish name.';

-- ============================================
-- 3. SEED DEFAULT DISHES (Your Menu Items)
-- ============================================

-- First, we need a system user to be the creator
-- We'll use the first admin user, or create a system UUID
-- Option: Create a system profile for seeded data
INSERT INTO profiles (id, name, role)
VALUES (
    '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid,
    'System',
    'admin'
)
ON CONFLICT (id) DO NOTHING;

-- Insert default dishes from your menu
INSERT INTO dishes (name, category, description, created_by, is_active) VALUES
    -- MEAT CATEGORY
    ('Biryani', 'meat', 'Arre bhai! Ye woh legendary biryani hai jis ke aage sab ghutne tek dete hain. Masalay daar chawal mein juicy gosht, dum pe pakaya hua, sath mein raita aur salad. Bas ek plate khao aur dopahar ki neend guaranteed! Office mein sab iske deewane hain, kyunke biryani = happiness formula hai.', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Chicken Karahi', 'meat', 'Bhai sahab, ye desi karahi hai na - woh jo kadhai mein dhoom dhadake se banti hai! Tamatar, mirchein, aur chicken ka shaandaar combination. Spicy bhi hai aur juicy bhi. Naan ke sath khao toh mazaa double ho jata hai. Warning: Ek plate mein control karna mushkil hai!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Chicken White Karahi', 'meat', 'Karahi ka posh cousin, jisko white gravy pasand hai! Ye wala spice kam hai lekin taste mein kami nahi. Malai aur dahi ki creamy gravy mein chicken tikke - bas khaane wale ki aankhein band ho jati hain. Jo teekha nahi kha sakte, unke liye perfect option hai.', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Qeema Aloo', 'meat', 'Desi comfort food! Qeema aur aloo ka jodi itna strong hai ke Sholay ki Jai-Veeru bhi sharmaa jayen. Ghar jaisa taste chahiye office mein? Ye order karo aur mummy ki yaad aa jayegi. Roti ke sath ya chawal ke sath - dono taraf se superhit!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Qeema Matar', 'meat', 'Qeema ka doosra avatar! Isme pyari pyari hari matar hain jo qeeme ke sath milke kamaal ka taste deti hain. Thoda healthy feel bhi ho jata hai matar ki wajah se (matlab zyada guilt nahi hoti second serving mein!). Bacchay bhi kha lete hain, bade bhi khush ho jate hain.', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Palak Chicken', 'meat', 'Popeye the Sailor Man ka favorite! Green hai toh healthy hai, chicken hai toh tasty hai - best of both worlds. Palak aur chicken ka milan bilkul superhit movie ki tarah hai. Jo bolte hain ke palak khana boring hai, unko ye dish try karwa ke dekho - munnh band ho jayega!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Shaljam Chicken Chawal', 'meat', 'Winter special item! Shaljam (turnip) aur chicken ka combination sun ke ajeeb lagta hai par khaake dekhoge toh fan ban jaoge. Sardi mein ye khaoge toh body ko andar se warmth milti hai. Chawal ke sath serve hota hai toh complete meal ban jata hai - no tension!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Aloo Chicken', 'meat', 'Sab se safe choice! Aloo toh sabko pasand hai, chicken bhi sabko pasand hai - dono mila do toh dhamaka ho jata hai. Gravy itni zabardast banti hai ke roti khatam nahi hoti. Boss ke sath lunch ho ya teammates ke sath, ye dish kabhi flop nahi hoti!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Pindi Chicken', 'meat', 'Pindi style! Yani ke Rawalpindi wala swag. Thick gravy, desi masale, aur chicken jo zabaan pe lapat jaye. Ye dish bilkul straightforward hai - no bakwaas, seedha dil pe lagti hai. Naan ya roti dono ke sath match karta hai. Pindi boys ki pehli pasand!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    
    -- REGULAR CATEGORY
    ('Anda Tikki', 'regular', 'Monday ki naraazi khatam karne ka formula! Ande ke cutlets jo crispy hain bahar se aur soft hain andar se. Breakfast ya lunch mein ajaye toh din set. Naan ya paratha ke sath perfect combination. Pro tip: Chutney ke sath try karo, maza double!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Kari Pakora', 'regular', 'Ye woh dish hai jisko dekh ke mausam barish wala ban jata hai! Besan ke pakore jo dahi ki kadhi mein swimming kar rahe hote hain. Simple lagta hai par taste mein expert level hai. Chawal ke sath khaoge toh samajh aaega ke asli satisfaction kya cheez hoti hai. Grandma approved recipe!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Aloo wala Paratha', 'regular', 'Desi breakfast ka baadshah! Paratha andar se aloo masala se bhara hua, upar se butter laga hua. Raita, achar, aur chai ke sath - life set hai boss! Office mein late ho gaye aur breakfast miss ho gaya? Lunch mein ye order karo aur dhoom machao. Taste bomb guaranteed!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    
    -- RICE CATEGORY
    ('Moong Daal Chawal', 'rice', 'Daal chawal matlab pyaar! Yellow moong daal jo ghee mein tadke ke sath shimmer kar rahi ho, upar se chawal. Light hai stomach pe, heavy hai taste mein. Isme achar aur papad milao toh lunch ka kya kehna! Health conscious ho ya foodie - sabke liye perfect hai.', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Masoor Daal Chawal', 'rice', 'Orange color ki masoor daal aur fluffy chawal - combination toh dekho! Protein bhi mil gaya, carbs bhi mil gaye, taste bhi mil gaya. Meethi meethi daal jo bilkul comforting ho. Thakaan ho office mein? Ye khao aur energy wapis aa jati hai. Simple hai par superhit!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Moong Masoor Daal Chawal', 'rice', 'Dono daalon ka power combo! Moong aur masoor dono milakar jab pakti hain toh taste alag level ka ban jata hai. Ye wala option confusion door karta hai - dono chaahiye the na, toh dono le lo! Nutrition double, taste bhi double. Smart choice for smart people!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Sabzi Pulao', 'rice', 'Colorful rice jo Instagram pe photo deserve karta hai! Pulao mein gajar, matar, aloo sab kuch mixed. Spices ka balance perfect hai - na zyada teekha, na bilkul fheeka. Raita ke sath combination toh killer hai. Vegetarian option chahiye? Ye lo boss, maza aa jayega!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    
    -- SABZI CATEGORY
    ('Bhindi', 'sabzi', 'Okra ka desi style transformation! Bhindi jo crispy bhi hai aur masaledar bhi. Pehle sabzi boring lagti thi? Ye wali try karo - opinion change ho jayega. Roti ke sath perfect match. Fun fact: Ye woh rare sabzi hai jisko non-veg lovers bhi appreciate karte hain!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true),
    ('Mix Sabzi', 'sabzi', 'Sabziyon ka Avengers team! Aloo, gajar, matar, shimla mirch - sab mil ke dhamaka karte hain. Healthy khana hai par taste mein compromise nahi? Ye lo solution! Desi masalon ke sath cooked, roti ke sath served. Thursday ko sabzi ka din hai toh sahi, par taste mein koi kami nahi!', '8719d2d8-631f-47de-a3df-8c4593fa7814'::uuid, true)
ON CONFLICT DO NOTHING;

-- ============================================
-- 4. HELPER FUNCTION TO PROMOTE USER TO ADMIN/HR
-- ============================================

-- Function to promote a user (can be called from SQL editor)
CREATE OR REPLACE FUNCTION promote_user_role(
    user_email TEXT,
    new_role user_role
)
RETURNS TABLE(user_id UUID, user_name TEXT, old_role user_role, updated_role user_role) AS $$
BEGIN
    RETURN QUERY
    UPDATE profiles
    SET role = new_role
    FROM auth.users
    WHERE profiles.id = auth.users.id
    AND auth.users.email = user_email
    RETURNING profiles.id, profiles.name, profiles.role AS old_role, new_role AS updated_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION promote_user_role IS 'Promote a user to admin or hr role. Usage: SELECT * FROM promote_user_role(''user@example.com'', ''admin'');';

-- ============================================
-- 5. VIEW: ACTIVE DISHES BY CATEGORY
-- ============================================

-- Convenient view to see all active dishes grouped by category
CREATE OR REPLACE VIEW dishes_by_category AS
SELECT 
    category,
    json_agg(
        json_build_object(
            'id', id,
            'name', name,
            'description', description,
            'estimated_cost', estimated_cost
        ) ORDER BY name
    ) as dishes
FROM dishes
WHERE is_active = true
GROUP BY category;

COMMENT ON VIEW dishes_by_category IS 'View of all active dishes grouped by category for easy selection';

-- ============================================
-- 6. FUNCTION: GET DISHES FOR CATEGORY
-- ============================================

-- Function to get all active dishes for a specific category
CREATE OR REPLACE FUNCTION get_dishes_for_category(p_category meal_category)
RETURNS TABLE(
    id UUID,
    name TEXT,
    description TEXT,
    estimated_cost DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.name,
        d.description,
        d.estimated_cost
    FROM dishes d
    WHERE d.category = p_category
    AND d.is_active = true
    ORDER BY d.name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_dishes_for_category IS 'Get all active dishes for a specific category. Usage: SELECT * FROM get_dishes_for_category(''meat'');';

-- ============================================
-- VERIFICATION QUERIES (Run these to test)
-- ============================================

-- Check if dishes were inserted
-- SELECT category, COUNT(*) FROM dishes GROUP BY category;

-- Check if system user exists
-- SELECT * FROM profiles WHERE role = 'admin';

-- Example: Promote a user to admin (replace email)
-- SELECT * FROM promote_user_role('your-email@example.com', 'admin');

-- Example: Get all meat dishes
-- SELECT * FROM get_dishes_for_category('meat');
