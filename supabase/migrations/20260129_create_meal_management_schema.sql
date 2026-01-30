-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create ENUMs
CREATE TYPE meal_category AS ENUM ('meat', 'regular', 'rice', 'sabzi');
CREATE TYPE day_of_week AS ENUM ('monday', 'tuesday', 'wednesday', 'thursday', 'friday');
CREATE TYPE user_role AS ENUM ('employee', 'hr', 'admin');
CREATE TYPE suggestion_status AS ENUM ('pending', 'approved', 'rejected');

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================
-- PROFILES TABLE
-- ============================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'employee',
    whatsapp_number TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create trigger for profiles updated_at
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- DISHES TABLE
-- ============================================
CREATE TABLE dishes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    category meal_category NOT NULL,
    description TEXT,
    estimated_cost DECIMAL(10, 2),
    ingredients JSONB,
    serving_size INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create trigger for dishes updated_at
CREATE TRIGGER update_dishes_updated_at
    BEFORE UPDATE ON dishes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create index for faster category filtering
CREATE INDEX idx_dishes_category ON dishes(category);
CREATE INDEX idx_dishes_is_active ON dishes(is_active);

-- ============================================
-- MEAL SUGGESTIONS TABLE
-- ============================================
CREATE TABLE meal_suggestions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dish_name TEXT NOT NULL,
    category meal_category NOT NULL,
    description TEXT,
    suggested_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status suggestion_status NOT NULL DEFAULT 'pending',
    reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    vote_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for faster filtering
CREATE INDEX idx_meal_suggestions_status ON meal_suggestions(status);
CREATE INDEX idx_meal_suggestions_category ON meal_suggestions(category);
CREATE INDEX idx_meal_suggestions_suggested_by ON meal_suggestions(suggested_by);

-- ============================================
-- SUGGESTION VOTES TABLE
-- ============================================
CREATE TABLE suggestion_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    suggestion_id UUID NOT NULL REFERENCES meal_suggestions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(suggestion_id, user_id)
);

-- Create index for faster vote counting
CREATE INDEX idx_suggestion_votes_suggestion_id ON suggestion_votes(suggestion_id);

-- Create trigger to update vote_count on meal_suggestions
CREATE OR REPLACE FUNCTION update_suggestion_vote_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE meal_suggestions
        SET vote_count = vote_count + 1
        WHERE id = NEW.suggestion_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE meal_suggestions
        SET vote_count = vote_count - 1
        WHERE id = OLD.suggestion_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_vote_count_on_insert
    AFTER INSERT ON suggestion_votes
    FOR EACH ROW
    EXECUTE FUNCTION update_suggestion_vote_count();

CREATE TRIGGER update_vote_count_on_delete
    AFTER DELETE ON suggestion_votes
    FOR EACH ROW
    EXECUTE FUNCTION update_suggestion_vote_count();

-- ============================================
-- WEEKLY MENUS TABLE
-- ============================================
CREATE TABLE weekly_menus (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    week_start_date DATE NOT NULL,
    week_end_date DATE NOT NULL,
    is_locked BOOLEAN NOT NULL DEFAULT false,
    locked_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    locked_at TIMESTAMPTZ,
    sent_to_cook BOOLEAN NOT NULL DEFAULT false,
    sent_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_week_dates CHECK (week_end_date >= week_start_date)
);

-- Create trigger for weekly_menus updated_at
CREATE TRIGGER update_weekly_menus_updated_at
    BEFORE UPDATE ON weekly_menus
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create index for faster date range queries
CREATE INDEX idx_weekly_menus_week_start ON weekly_menus(week_start_date);
CREATE INDEX idx_weekly_menus_is_locked ON weekly_menus(is_locked);

-- ============================================
-- MENU ITEMS TABLE
-- ============================================
CREATE TABLE menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    weekly_menu_id UUID NOT NULL REFERENCES weekly_menus(id) ON DELETE CASCADE,
    day_of_week day_of_week NOT NULL,
    dish_id UUID NOT NULL REFERENCES dishes(id) ON DELETE CASCADE,
    category meal_category NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(weekly_menu_id, day_of_week)
);

-- Create index for faster menu queries
CREATE INDEX idx_menu_items_weekly_menu_id ON menu_items(weekly_menu_id);
CREATE INDEX idx_menu_items_day_of_week ON menu_items(day_of_week);

-- ============================================
-- CATEGORY SCHEDULE TABLE
-- ============================================
CREATE TABLE category_schedule (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    day_of_week day_of_week NOT NULL UNIQUE,
    category meal_category NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- Insert default schedule
INSERT INTO category_schedule (day_of_week, category, is_active) VALUES
    ('monday', 'regular', true),
    ('tuesday', 'meat', true),
    ('wednesday', 'rice', true),
    ('thursday', 'sabzi', true),
    ('friday', 'meat', true);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE dishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE suggestion_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_menus ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE category_schedule ENABLE ROW LEVEL SECURITY;

-- ============================================
-- PROFILES POLICIES
-- ============================================
-- Users can view all profiles
CREATE POLICY "Users can view all profiles"
    ON profiles FOR SELECT
    USING (true);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- ============================================
-- DISHES POLICIES
-- ============================================
-- Everyone can view active dishes
CREATE POLICY "Everyone can view active dishes"
    ON dishes FOR SELECT
    USING (is_active = true OR created_by = auth.uid());

-- Employees can create dishes
CREATE POLICY "Employees can create dishes"
    ON dishes FOR INSERT
    WITH CHECK (auth.uid() = created_by);

-- Only dish creator or admin/hr can update
CREATE POLICY "Dish creator or admin can update dishes"
    ON dishes FOR UPDATE
    USING (
        created_by = auth.uid() 
        OR EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'hr')
        )
    );

-- Only dish creator or admin/hr can delete
CREATE POLICY "Dish creator or admin can delete dishes"
    ON dishes FOR DELETE
    USING (
        created_by = auth.uid() 
        OR EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'hr')
        )
    );

-- ============================================
-- MEAL SUGGESTIONS POLICIES
-- ============================================
-- Everyone can view meal suggestions
CREATE POLICY "Everyone can view meal suggestions"
    ON meal_suggestions FOR SELECT
    USING (true);

-- Employees can create suggestions
CREATE POLICY "Employees can create suggestions"
    ON meal_suggestions FOR INSERT
    WITH CHECK (auth.uid() = suggested_by);

-- Only admin/hr can update suggestions (approve/reject)
CREATE POLICY "Admin/HR can update suggestions"
    ON meal_suggestions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'hr')
        )
    );

-- Users can delete their own pending suggestions
CREATE POLICY "Users can delete own pending suggestions"
    ON meal_suggestions FOR DELETE
    USING (suggested_by = auth.uid() AND status = 'pending');

-- ============================================
-- SUGGESTION VOTES POLICIES
-- ============================================
-- Everyone can view votes
CREATE POLICY "Everyone can view votes"
    ON suggestion_votes FOR SELECT
    USING (true);

-- Users can vote (insert)
CREATE POLICY "Users can vote"
    ON suggestion_votes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own votes
CREATE POLICY "Users can delete own votes"
    ON suggestion_votes FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- WEEKLY MENUS POLICIES
-- ============================================
-- Everyone can view weekly menus
CREATE POLICY "Everyone can view weekly menus"
    ON weekly_menus FOR SELECT
    USING (true);

-- Only admin/hr can create weekly menus
CREATE POLICY "Admin/HR can create weekly menus"
    ON weekly_menus FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'hr')
        )
    );

-- Only admin/hr can update weekly menus
CREATE POLICY "Admin/HR can update weekly menus"
    ON weekly_menus FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'hr')
        )
    );

-- Only admin/hr can delete weekly menus
CREATE POLICY "Admin/HR can delete weekly menus"
    ON weekly_menus FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'hr')
        )
    );

-- ============================================
-- MENU ITEMS POLICIES
-- ============================================
-- Everyone can view menu items
CREATE POLICY "Everyone can view menu items"
    ON menu_items FOR SELECT
    USING (true);

-- Only admin/hr can create menu items
CREATE POLICY "Admin/HR can create menu items"
    ON menu_items FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'hr')
        )
    );

-- Only admin/hr can update menu items
CREATE POLICY "Admin/HR can update menu items"
    ON menu_items FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'hr')
        )
    );

-- Only admin/hr can delete menu items
CREATE POLICY "Admin/HR can delete menu items"
    ON menu_items FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role IN ('admin', 'hr')
        )
    );

-- ============================================
-- CATEGORY SCHEDULE POLICIES
-- ============================================
-- Everyone can view category schedule
CREATE POLICY "Everyone can view category schedule"
    ON category_schedule FOR SELECT
    USING (true);

-- Only admin can modify category schedule
CREATE POLICY "Admin can modify category schedule"
    ON category_schedule FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role = 'admin'
        )
    );

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to get user role
CREATE OR REPLACE FUNCTION get_user_role(user_id UUID)
RETURNS user_role AS $$
    SELECT role FROM profiles WHERE id = user_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- Function to check if user is admin or hr
CREATE OR REPLACE FUNCTION is_admin_or_hr(user_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = user_id 
        AND role IN ('admin', 'hr')
    );
$$ LANGUAGE sql SECURITY DEFINER;

-- Function to validate menu item category matches schedule
CREATE OR REPLACE FUNCTION validate_menu_item_category()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM category_schedule
        WHERE day_of_week = NEW.day_of_week
        AND category = NEW.category
        AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Category % is not valid for % according to schedule', 
            NEW.category, NEW.day_of_week;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to validate menu item category
CREATE TRIGGER validate_menu_item_category_trigger
    BEFORE INSERT OR UPDATE ON menu_items
    FOR EACH ROW
    EXECUTE FUNCTION validate_menu_item_category();

-- ============================================
-- COMMENTS (Documentation)
-- ============================================

COMMENT ON TABLE profiles IS 'User profiles extending auth.users with role and contact info';
COMMENT ON TABLE dishes IS 'Available dishes/recipes in the system';
COMMENT ON TABLE meal_suggestions IS 'Employee suggestions for new dishes';
COMMENT ON TABLE suggestion_votes IS 'Votes on meal suggestions by employees';
COMMENT ON TABLE weekly_menus IS 'Weekly meal plans for the office';
COMMENT ON TABLE menu_items IS 'Individual meals assigned to specific days in weekly menus';
COMMENT ON TABLE category_schedule IS 'Default category schedule for each day of the week';

COMMENT ON COLUMN profiles.role IS 'User role: employee, hr, or admin';
COMMENT ON COLUMN dishes.estimated_cost IS 'Estimated cost in local currency';
COMMENT ON COLUMN dishes.ingredients IS 'JSON array of ingredients with quantities';
COMMENT ON COLUMN meal_suggestions.vote_count IS 'Automatically updated count of votes';
COMMENT ON COLUMN weekly_menus.is_locked IS 'Once locked, menu cannot be modified';
COMMENT ON COLUMN weekly_menus.sent_to_cook IS 'Tracks if menu has been sent via WhatsApp';
