-- SQL migration: Add status change trigger to ride_requests
-- Resolves passenger cancellation driver availability lock.

CREATE OR REPLACE FUNCTION public.handle_ride_request_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- If status changes to 'Cancelled' or 'Completed' (case-insensitive)
    IF (NEW.status = 'Cancelled' OR NEW.status = 'Completed' OR NEW.status = 'cancelled' OR NEW.status = 'completed') 
       AND OLD.driver_id IS NOT NULL THEN
        UPDATE public.drivers
        SET is_available = true,
            updated_at = NOW()
        WHERE id = OLD.driver_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_ride_request_status_change ON public.ride_requests;

CREATE TRIGGER trg_ride_request_status_change
    AFTER UPDATE OF status ON public.ride_requests
    FOR EACH ROW
    WHEN (NEW.status IN ('Cancelled', 'Completed', 'cancelled', 'completed'))
    EXECUTE FUNCTION public.handle_ride_request_status_change();
