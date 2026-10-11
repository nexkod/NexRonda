package main

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
	lksdk "github.com/livekit/server-sdk-go/v2"
	"github.com/redis/go-redis/v9"
)

type Config struct {
	Port            string
	RedisURL        string
	LiveKitURL      string
	LiveKitAPIKey   string
	LiveKitAPISecret string
}

type Server struct {
	cfg        Config
	rdb        *redis.Client
	roomClient *lksdk.RoomServiceClient
}

type CreateRoomRequest struct {
	Name       string `json:"name" binding:"required"`
	CreatorID  string `json:"creator_id" binding:"required"`
	RiderName  string `json:"rider_name" binding:"required"`
}

type JoinRoomRequest struct {
	PIN       string `json:"pin" binding:"required"`
	RiderID   string `json:"rider_id" binding:"required"`
	RiderName string `json:"rider_name" binding:"required"`
}

type TokenResponse struct {
	Token     string `json:"token"`
	RoomName  string `json:"room_name"`
	RoomPIN   string `json:"room_pin"`
	LiveKitURL string `json:"livekit_url"`
}

func generate6DigitPIN() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(900000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()+100000), nil
}

func (s *Server) createLiveKitToken(roomName, identity, name string) (string, error) {
	at := auth.NewAccessToken(s.cfg.LiveKitAPIKey, s.cfg.LiveKitAPISecret)
	grant := &auth.VideoGrant{
		RoomJoin: true,
		Room:     roomName,
		CanPublish: boolPtr(true),
		CanSubscribe: boolPtr(true),
	}
	at.AddGrant(grant).
		SetIdentity(identity).
		SetName(name).
		SetValidFor(24 * time.Hour)

	return at.ToJWT()
}

func boolPtr(b bool) *bool {
	return &b
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "localhost:6379"
	}
	lkURL := os.Getenv("LIVEKIT_URL")
	if lkURL == "" {
		lkURL = "http://localhost:7880"
	}
	lkKey := os.Getenv("LIVEKIT_API_KEY")
	if lkKey == "" {
		lkKey = "devkey"
	}
	lkSecret := os.Getenv("LIVEKIT_API_SECRET")
	if lkSecret == "" {
		lkSecret = "secretsecretsecretsecretsecretsecret32"
	}

	cfg := Config{
		Port:            port,
		RedisURL:        redisURL,
		LiveKitURL:      lkURL,
		LiveKitAPIKey:   lkKey,
		LiveKitAPISecret: lkSecret,
	}

	rdb := redis.NewClient(&redis.Options{
		Addr: cfg.RedisURL,
	})

	var roomClient *lksdk.RoomServiceClient
	if cfg.LiveKitURL != "" && cfg.LiveKitAPIKey != "" && cfg.LiveKitAPISecret != "" {
		roomClient = lksdk.NewRoomServiceClient(cfg.LiveKitURL, cfg.LiveKitAPIKey, cfg.LiveKitAPISecret)
	}

	srv := &Server{
		cfg:        cfg,
		rdb:        rdb,
		roomClient: roomClient,
	}

	router := gin.Default()

	// CORS middleware for Flutter web/mobile
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "healthy",
			"app":    "NexRonda Signaling",
		})
	})

	// Create Room & Issue Token
	router.POST("/api/rooms/create", func(c *gin.Context) {
		var req CreateRoomRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		pin, err := generate6DigitPIN()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate PIN"})
			return
		}

		roomKey := fmt.Sprintf("nexronda:room:%s", pin)
		ctx := context.Background()
		// Store room metadata for 24h
		err = srv.rdb.HSet(ctx, roomKey, map[string]interface{}{
			"name":       req.Name,
			"pin":        pin,
			"creator_id": req.CreatorID,
			"created_at": time.Now().Unix(),
		}).Err()

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save room to Redis"})
			return
		}
		srv.rdb.Expire(ctx, roomKey, 24*time.Hour)

		token, err := srv.createLiveKitToken(pin, req.CreatorID, req.RiderName)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mint LiveKit token"})
			return
		}

		c.JSON(http.StatusOK, TokenResponse{
			Token:      token,
			RoomName:   req.Name,
			RoomPIN:    pin,
			LiveKitURL: srv.cfg.LiveKitURL,
		})
	})

	// Join Room by 6-digit PIN
	router.POST("/api/rooms/join", func(c *gin.Context) {
		var req JoinRoomRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		roomKey := fmt.Sprintf("nexronda:room:%s", req.PIN)
		ctx := context.Background()
		vals, err := srv.rdb.HGetAll(ctx, roomKey).Result()
		if err != nil || len(vals) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Invalid or expired convoy PIN"})
			return
		}

		roomName := vals["name"]
		token, err := srv.createLiveKitToken(req.PIN, req.RiderID, req.RiderName)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mint LiveKit token"})
			return
		}

		c.JSON(http.StatusOK, TokenResponse{
			Token:      token,
			RoomName:   roomName,
			RoomPIN:    req.PIN,
			LiveKitURL: srv.cfg.LiveKitURL,
		})
	})

	// End Convoy Room (Host only)
	router.POST("/api/rooms/end", func(c *gin.Context) {
		var req struct {
			PIN       string `json:"pin" binding:"required"`
			CreatorID string `json:"creator_id" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		roomKey := fmt.Sprintf("nexronda:room:%s", req.PIN)
		ctx := context.Background()
		creator, err := srv.rdb.HGet(ctx, roomKey, "creator_id").Result()
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Room not found or already ended"})
			return
		}

		if creator != req.CreatorID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only the convoy host can end the ride for all"})
			return
		}

		srv.rdb.Del(ctx, roomKey)
		c.JSON(http.StatusOK, gin.H{
			"status":  "ended",
			"message": "Convoy room has been ended successfully",
		})
	})

	// Global LiveKit Usage & Cloud Limit
	router.GET("/api/usage", func(c *gin.Context) {
		ctx := c.Request.Context()

		activeRooms := 0
		activeParticipants := 0
		var liveRoomsList []gin.H

		if srv.roomClient != nil {
			resp, err := srv.roomClient.ListRooms(ctx, &livekit.ListRoomsRequest{})
			if err == nil && resp != nil {
				activeRooms = len(resp.Rooms)
				for _, r := range resp.Rooms {
					activeParticipants += int(r.NumParticipants)
					liveRoomsList = append(liveRoomsList, gin.H{
						"name":         r.Name,
						"participants": r.NumParticipants,
						"creation_time": r.CreationTime,
					})
				}
			}
		}

		// Count registered redis rooms
		redisKeys, _ := srv.rdb.Keys(ctx, "nexronda:room:*").Result()

		// LiveKit Cloud standard free / developer tier limits
		// 100 max concurrent participants, 50 GB monthly bandwidth
		const cloudMaxParticipants = 100
		const cloudMaxBandwidthGB = 50.0

		c.JSON(http.StatusOK, gin.H{
			"livekit": gin.H{
				"url":                  srv.cfg.LiveKitURL,
				"active_rooms":         activeRooms,
				"active_participants":  activeParticipants,
				"max_participants":     cloudMaxParticipants,
				"participant_usage_pct": float64(activeParticipants) / float64(cloudMaxParticipants) * 100.0,
				"max_bandwidth_gb":     cloudMaxBandwidthGB,
				"plan":                 "LiveKit Cloud Standard",
				"status":               "healthy",
			},
			"convoys": gin.H{
				"registered_rooms": len(redisKeys),
				"active_rooms":     liveRoomsList,
			},
			"server_time": time.Now().Unix(),
		})
	})

	router.Run(":" + srv.cfg.Port)
}
