// Reproduction supplied in issue #1322, comment 6647143378.
// https://github.com/Chevey339/kelivo/issues/1322#issuecomment-6647143378
const complexMermaidExamples = <String, String>{
  'microservices': r'''
flowchart TB
    subgraph Client["Client Layer"]
        Web["Web App"]
        Mobile["Mobile App"]
        Admin["Admin Dashboard"]
    end

    subgraph Gateway["API Gateway / BFF"]
        Auth["Auth Service<br/>OAuth2 + JWT"]
        Rate["Rate Limiter"]
        Router["Router"]
    end

    subgraph Core["Core Services"]
        direction TB
        Order["Order Service"]
        Payment["Payment Service"]
        Inventory["Inventory Service"]
        Notify["Notification Service"]
        Search["Search Service"]
    end

    subgraph Data["Data Layer"]
        PG[("PostgreSQL<br/>Primary DB")]
        Redis[("Redis<br/>Cache / Sessions")]
        ES[("Elasticsearch")]
        S3[("S3<br/>Object Storage")]
        MQ["Kafka<br/>Event Bus"]
    end

    subgraph External["External"]
        Stripe["Stripe"]
        SendGrid["SendGrid"]
        Twilio["Twilio SMS"]
    end

    Web --> Router
    Mobile --> Router
    Admin --> Router
    Router --> Auth
    Router --> Rate
    Router --> Order
    Router --> Payment
    Router --> Search

    Order --> PG
    Order --> Redis
    Order --> MQ
    Payment --> PG
    Payment --> Stripe
    Payment --> MQ
    Inventory --> PG
    Inventory --> Redis
    Notify --> MQ
    Notify --> SendGrid
    Notify --> Twilio
    Search --> ES
    Order --> S3

    classDef client fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef data fill:#fff3e0,stroke:#e65100,stroke-width:2px
    class Web,Mobile,Admin client
    class PG,Redis,ES,S3,MQ data
''',
  'checkout': r'''
sequenceDiagram
    autonumber
    actor User
    participant Web as Web App
    participant API as API Gateway
    participant Auth as Auth Server
    participant Pay as Payment Service
    participant DB as Database

    User->>Web: Browse / Checkout
    Web->>API: GET /checkout
    API->>Auth: Validate Token?
    Auth-->>API: Token Valid (JWT)
    API-->>Web: Checkout Page

    User->>Web: Submit Payment
    Web->>API: POST /payments
    API->>Pay: Charge Card
    activate Pay
    Pay->>DB: Lock Funds
    DB-->>Pay: OK

    alt Charge Successful
        Pay-->>API: 200 OK + Payment ID
        API->>DB: Save Order
        API-->>Web: 201 Created
        Web-->>User: Confirmation Page
    else Charge Failed
        Pay-->>API: 402 Failed
        API-->>Web: Error Details
        Web-->>User: Show Retry UI
    end
    deactivate Pay

    Note over Web,User: User can retry up to 3 times

    loop Daily Reconciliation
        Pay->>DB: Sync Transactions
    end
''',
  'classes': r'''
classDiagram
    class Customer {
        +String id
        +String email
        +String name
        +PlaceOrder() Order
        +GetHistory() List~Order~
    }
    class Order {
        +UUID id
        +DateTime createdAt
        +OrderStatus status
        +Decimal total
        +AddItem(Product, int)
        +Checkout() bool
    }
    class OrderItem {
        +Product product
        +int quantity
        +Decimal price
    }
    class Product {
        +String sku
        +String title
        +Decimal price
        +int stock
        +IsAvailable() bool
    }
    class PhysicalProduct {
        +Decimal weight
        +String dimensions
    }
    class DigitalProduct {
        +String downloadUrl
    }
    class Payment {
        +UUID id
        +Decimal amount
        +PaymentMethod method
        +Process() bool
    }
    class OrderStatus {
        <<enumeration>>
        PENDING
        PAID
        SHIPPED
        DELIVERED
        CANCELLED
    }

    Customer "1" --> "0..*" Order : places
    Order "1" *-- "1..*" OrderItem : contains
    OrderItem --> Product : references
    Order "1" --> "0..1" Payment : paid by
    Order --> OrderStatus
    Product <|-- PhysicalProduct
    Product <|-- DigitalProduct
''',
  'entities': r'''
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ ORDER_ITEM : contains
    PRODUCT ||--o{ ORDER_ITEM : "is in"
    CUSTOMER ||--o{ REVIEW : writes
    PRODUCT ||--o{ REVIEW : receives
    CATEGORY ||--o{ PRODUCT : has

    CUSTOMER {
        uuid id PK
        string email UK
        string name
        timestamp created_at
    }
    ORDER {
        uuid id PK
        uuid customer_id FK
        string status
        decimal total
        timestamp created_at
    }
    PRODUCT {
        uuid id PK
        uuid category_id FK
        string sku UK
        string title
        decimal price
        int stock
    }
    ORDER_ITEM {
        uuid order_id PK,FK
        uuid product_id PK,FK
        int quantity
        decimal unit_price
    }
    REVIEW {
        uuid id PK
        uuid customer_id FK
        uuid product_id FK
        int rating
        text comment
    }
    CATEGORY {
        uuid id PK
        string name
        string slug UK
    }
''',
  'states': r'''
stateDiagram-v2
    [*] --> Cart
    state Cart {
        [*] --> Empty
        Empty --> ItemsAdded : Add Item
        ItemsAdded --> ItemsAdded : Update Qty
        ItemsAdded --> Empty : Remove All
    }
    Cart --> Checkout : Checkout
    Checkout --> PaymentPending
    PaymentPending --> Paid : Payment Success
    PaymentPending --> Failed : Payment Failed
    Failed --> Checkout : Retry
    Paid --> Processing
    Processing --> Shipped
    Shipped --> Delivered
    Delivered --> [*]
    Processing --> Cancelled : Cancel
    Paid --> Cancelled : Refund
''',
  'gantt': r'''
gantt
    title Product Launch Timeline
    dateFormat YYYY-MM-DD
    axisFormat %d %b

    section Discovery
    Stakeholder Interviews :done, d1, 2026-01-05, 10d
    Requirements & Spec : d2, after d1, 15d
    UX Research : d3, after d1, 12d

    section Design
    User Flows :crit, des1, after d2, 10d
    UI Design : des2, after des1, 20d
    Design Review :des3, after des2, 5d

    section Development
    Backend API :crit, dev1, after d2, 30d
    Frontend : dev2, after des1, 25d
    Integration & QA : dev3, after dev1, 15d

    section Launch
    Beta Testing : launch1, after dev3, 14d
    Marketing Prep : launch2, after des3, 20d
    Production Deploy :milestone, m1, after launch1, 0d
    Public Launch :milestone, m2, after launch2, 0d
''',
  'git': r'''
gitGraph
    commit id: "init"
    commit id: "readme"
    branch develop
    checkout develop
    commit id: "feat: auth"
    commit id: "feat: ui"
    branch feature/payments
    commit id: "stripe integration"
    commit id: "webhook handler"
    checkout develop
    merge feature/payments id: "merge payments"
    branch hotfix/bug-123
    checkout hotfix/bug-123
    commit id: "fix null check"
    checkout main
    merge hotfix/bug-123 id: "hotfix to main"
    checkout develop
    commit id: "release prep"
    checkout main
    merge develop id: "v1.0 release"
    commit id: "tag v1.0" tag: "v1.0.0"
''',
  'mindmap': r'''
mindmap
  root((Full-Stack App))
    Frontend
      React
      TypeScript
      Tailwind
      Vite
    Backend
      Node.js
      PostgreSQL
      Redis
      GraphQL
    DevOps
      Docker
      GitHub Actions
      AWS
      Terraform
    Testing
      Vitest
      Playwright
      Cypress
''',
  'timeline': r'''
timeline
    title Company History
    2020 : Founded
         : Seed Round
    2021 : Launched MVP
         : 10k Users
    2022 : Series A
         : Expanded to EU
    2023 : Launched Mobile App
         : 500k Users
    2024 : Series B
         : AI Features
    2025 : IPO
''',
  'pie': r'''
pie title Traffic Sources
    "Organic Search" : 42
    "Social Media" : 28
    "Direct" : 18
    "Referral" : 8
    "Email" : 4
''',
  'quadrant': r'''
quadrantChart
    title Reach and Engagement
    x-axis Low Reach --> High Reach
    y-axis Low Engagement --> High Engagement
    quadrant-1 Top Performers
    quadrant-2 Hidden Gems
    quadrant-3 Low Priority
    quadrant-4 Broadcasters
    Campaign A: [0.85, 0.90]
    Campaign B: [0.30, 0.85]
    Campaign C: [0.20, 0.25]
    Campaign D: [0.80, 0.30]
''',
  'c4': r'''
C4Context
    title System Context Diagram
    Person(user, "Customer", "A customer of the shop")
    System(shop, "Online Shop", "Allows customers to buy products")
    Person(admin, "Admin", "Manages products")
    System_Ext(payment, "Payment Gateway", "Processes payments")
    System_Ext(email, "Email System", "Sends notifications")

    Rel(user, shop, "Uses")
    Rel(admin, shop, "Manages")
    Rel(shop, payment, "Uses")
    Rel(shop, email, "Uses")
''',
};
